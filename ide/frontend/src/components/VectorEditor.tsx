/**
 * VectorEditor - Visual editor for .vec vector resources
 * 
 * A canvas-based editor for creating and editing Vectrex vector graphics.
 * Features:
 * - Background image layer for tracing
 * - Automatic edge detection to generate vectors from images
 * - Drawing tools: Select, Pen
 * - Layers panel with visibility toggles
 */

import React, { useRef, useEffect, useState, useCallback } from 'react';
import { useEditorStore } from '../state/editorStore.js';
import DxfParser from 'dxf-parser';
import type { IEntity } from 'dxf-parser';

// Types from the .vec format
interface Point {
  x: number;
  y: number;
  z?: number; // Optional Z coordinate for 3D vectors
  t?: 'a' | 'c'; // Bezier: 'a'=anchor, 'c'=control point
}

interface VecPath {
  name: string;
  intensity: number;
  closed: boolean;
  type?: 'polyline' | 'bezier';
  points: Point[];
}

interface Layer {
  name: string;
  visible: boolean;
  paths: VecPath[];
}

interface CollisionSegment {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

interface VecResource {
  version: string;
  name: string;
  author: string;
  created: string;
  canvas: {
    width: number;
    height: number;
    origin: string;
  };
  layers: Layer[];
  animations: any[];
  metadata: {
    hitbox: { x: number; y: number; w: number; h: number } | null;
    origin: Point | null;
    tags: string[];
  };
  // Design-time calculated center (mirror axis)
  center_x?: number;
  center_y?: number;
  // Background image stored as base64 data URL
  backgroundImage?: string;
  // Background image offset in canvas pixels
  backgroundOffset?: { x: number; y: number };
  collisionMesh?: {
    segments: CollisionSegment[];
  };
  /** Reusable walkable areas (Phase 2 wander AI). Coordinates are relative
   *  to the vec's origin; the playground / codegen translate them by each
   *  placed object's (x, y). Inheritance: .vec → .vplay → .venemy. */
  walkableAreas?: { y: number; x_min: number; x_max: number }[];
}

interface VectorEditorProps {
  /** Initial resource to edit */
  resource?: VecResource;
  /** Callback when resource changes */
  onChange?: (resource: VecResource) => void;
  /** Width of the editor */
  width?: number;
  /** Height of the editor */
  height?: number;
}

type Tool = 'select' | 'pen' | 'line' | 'bezier' | 'polygon' | 'circle' | 'arc' | 'pan' | 'background' | 'walkarea';
type ViewMode = 'xy' | 'xz' | 'yz' | '3d';

const defaultResource: VecResource = {
  version: '1.0',
  name: 'untitled',
  author: '',
  created: '',
  canvas: { width: 256, height: 256, origin: 'center' },
  layers: [{ name: 'default', visible: true, paths: [] }],
  animations: [],
  metadata: { hitbox: null, origin: null, tags: [] },
};

// ============================================
// Edge Detection Algorithm (Canny-like)
// ============================================

interface EdgeDetectionOptions {
  lowThreshold: number;
  highThreshold: number;
  simplifyTolerance: number;
  minPathLength: number;
  useBlur: boolean; // Whether to apply Gaussian blur (disable for thin lines)
}

const defaultEdgeOptions: EdgeDetectionOptions = {
  lowThreshold: 20,
  highThreshold: 60,
  simplifyTolerance: 2.0,
  minPathLength: 4,
  useBlur: false, // Disabled by default - better for pixel art / thin lines
};

/**
 * Apply Gaussian blur for noise reduction
 */
function gaussianBlur(imageData: ImageData): ImageData {
  const width = imageData.width;
  const height = imageData.height;
  const src = imageData.data;
  const output = new ImageData(width, height);
  const dst = output.data;

  // 5x5 Gaussian kernel (sigma ~1.4)
  const kernel = [
    1, 4, 6, 4, 1,
    4, 16, 24, 16, 4,
    6, 24, 36, 24, 6,
    4, 16, 24, 16, 4,
    1, 4, 6, 4, 1
  ];
  const kernelSum = 256;

  for (let y = 2; y < height - 2; y++) {
    for (let x = 2; x < width - 2; x++) {
      let r = 0, g = 0, b = 0;
      for (let ky = -2; ky <= 2; ky++) {
        for (let kx = -2; kx <= 2; kx++) {
          const idx = ((y + ky) * width + (x + kx)) * 4;
          const k = kernel[(ky + 2) * 5 + (kx + 2)];
          if (src[idx] !== undefined && k !== undefined) r += src[idx] * k;
          if (src[idx + 1] !== undefined && k !== undefined) g += src[idx + 1] * k;
          if (src[idx + 2] !== undefined && k !== undefined) b += src[idx + 2] * k;
        }
      }
      const dstIdx = (y * width + x) * 4;
      dst[dstIdx] = r / kernelSum;
      dst[dstIdx + 1] = g / kernelSum;
      dst[dstIdx + 2] = b / kernelSum;
      dst[dstIdx + 3] = 255;
    }
  }
  return output;
}

/**
 * Apply Sobel edge detection with gradient direction
 */
function sobelEdgeDetection(imageData: ImageData): { magnitude: Float32Array; direction: Float32Array; width: number; height: number } {
  const width = imageData.width;
  const height = imageData.height;
  const src = imageData.data;
  const magnitude = new Float32Array(width * height);
  const direction = new Float32Array(width * height);

  // Sobel kernels
  const sobelX = [-1, 0, 1, -2, 0, 2, -1, 0, 1];
  const sobelY = [-1, -2, -1, 0, 0, 0, 1, 2, 1];

  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      let gx = 0, gy = 0;
      
      for (let ky = -1; ky <= 1; ky++) {
        for (let kx = -1; kx <= 1; kx++) {
          const idx = ((y + ky) * width + (x + kx)) * 4;
          const gray = (src[idx] ?? 0) * 0.299 + (src[idx + 1] ?? 0) * 0.587 + (src[idx + 2] ?? 0) * 0.114;
          const kernelIdx = (ky + 1) * 3 + (kx + 1);
          gx += gray * (sobelX[kernelIdx] ?? 0);
          gy += gray * (sobelY[kernelIdx] ?? 0);
        }
      }
      
      const idx = y * width + x;
      magnitude[idx] = Math.sqrt(gx * gx + gy * gy);
      direction[idx] = Math.atan2(gy, gx);
    }
  }

  return { magnitude, direction, width, height };
}

/**
 * Non-Maximum Suppression - thin edges to single pixel width
 */
function nonMaximumSuppression(
  magnitude: Float32Array,
  direction: Float32Array,
  width: number,
  height: number
): Float32Array {
  const output = new Float32Array(width * height);

  for (let y = 1; y < height - 1; y++) {
    for (let x = 1; x < width - 1; x++) {
      const idx = y * width + x;
      const mag = magnitude[idx];
      const angle = direction[idx];
      
      // Determine gradient direction (0, 45, 90, 135 degrees)
      let neighbor1 = 0, neighbor2 = 0;
      const absAngle = Math.abs(angle ?? 0);
      
      if (absAngle < Math.PI / 8 || absAngle > 7 * Math.PI / 8) {
        // Horizontal edge - compare with left/right
        neighbor1 = magnitude[idx - 1] ?? 0;
        neighbor2 = magnitude[idx + 1] ?? 0;
      } else if (absAngle < 3 * Math.PI / 8) {
        // Diagonal edge (45 o -45)
        if ((angle ?? 0) > 0) {
          neighbor1 = magnitude[(y - 1) * width + (x + 1)] ?? 0;
          neighbor2 = magnitude[(y + 1) * width + (x - 1)] ?? 0;
        } else {
          neighbor1 = magnitude[(y - 1) * width + (x - 1)] ?? 0;
          neighbor2 = magnitude[(y + 1) * width + (x + 1)] ?? 0;
        }
      } else if (absAngle < 5 * Math.PI / 8) {
        // Vertical edge - compare with top/bottom
        neighbor1 = magnitude[(y - 1) * width + x] ?? 0;
        neighbor2 = magnitude[(y + 1) * width + x] ?? 0;
      } else {
        // Other diagonal
        if ((angle ?? 0) > 0) {
          neighbor1 = magnitude[(y - 1) * width + (x - 1)] ?? 0;
          neighbor2 = magnitude[(y + 1) * width + (x + 1)] ?? 0;
        } else {
          neighbor1 = magnitude[(y - 1) * width + (x + 1)] ?? 0;
          neighbor2 = magnitude[(y + 1) * width + (x - 1)] ?? 0;
        }
      }
      
      // Keep pixel only if it's a local maximum
      if (mag !== undefined && mag >= neighbor1 && mag >= neighbor2) {
        output[idx] = mag;
      }
    }
  }

  return output;
}

/**
 * Double threshold and hysteresis
 */
function hysteresisThreshold(
  magnitude: Float32Array,
  width: number,
  height: number,
  lowThreshold: number,
  highThreshold: number
): boolean[][] {
  const edges: boolean[][] = Array(height).fill(null).map(() => Array(width).fill(false));
  const strong: boolean[][] = Array(height).fill(null).map(() => Array(width).fill(false));
  
  // Mark strong and weak edges
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const mag = magnitude[y * width + x];
      if (mag !== undefined && mag >= highThreshold) {
        if (strong[y]) strong[y][x] = true;
        if (edges[y]) edges[y][x] = true;
      }
    }
  }
  
  // Hysteresis - connect weak edges to strong edges
  let changed = true;
  while (changed) {
    changed = false;
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        if (!edges[y] || edges[y][x]) continue;
        const mag = magnitude[y * width + x];
        if (mag === undefined || mag < lowThreshold) continue;
        
        // Check if connected to an edge
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (edges[y + dy] && edges[y + dy][x + dx]) {
              edges[y][x] = true;
              changed = true;
              break;
            }
          }
          if (edges[y] && edges[y][x]) break;
        }
      }
    }
  }

  return edges;
}

/**
 * Trace edge pixels into paths with better connectivity
 */
function traceEdgesToPaths(
  edges: boolean[][],
  imgWidth: number,
  imgHeight: number,
  imgDrawX: number,
  imgDrawY: number,
  imgDrawWidth: number,
  imgDrawHeight: number,
  canvasWidth: number,
  canvasHeight: number,
  resourceWidth: number,
  resourceHeight: number
): VecPath[] {
  if (!edges || edges.length === 0 || !edges[0]) return [];
  const height = edges.length;
  const width = edges[0].length;
  const visited: boolean[][] = Array(height).fill(null).map(() => Array(width).fill(false));
  const paths: VecPath[] = [];

  // Direction vectors for 8-connectivity - prioritize straight directions
  const dx = [1, 0, -1, 0, 1, 1, -1, -1];
  const dy = [0, 1, 0, -1, 1, -1, 1, -1];

  // Convert pixel coordinates to resource coordinates
  const pixelToResource = (px: number, py: number): Point => {
    // First, map from edge image coords to canvas coords
    const canvasX = imgDrawX + (px / width) * imgDrawWidth;
    const canvasY = imgDrawY + (py / height) * imgDrawHeight;
    
    // Then map from canvas coords to resource coords (centered)
    const centerX = canvasWidth / 2;
    const centerY = canvasHeight / 2;
    const scale = Math.min(canvasWidth, canvasHeight) / resourceWidth;
    
    return {
      x: Math.round((canvasX - centerX) / scale),
      y: Math.round((centerY - canvasY) / scale),
    };
  };

  for (let startY = 0; startY < height; startY++) {
    for (let startX = 0; startX < width; startX++) {
      if (!edges[startY]?.[startX] || visited[startY]?.[startX]) continue;

      // Start a new path
      const pathPixels: Array<{x: number, y: number}> = [];
      let x = startX, y = startY;

      while (true) {
        if (!visited[y]) break;
        visited[y][x] = true;
        pathPixels.push({ x, y });

        // Find next unvisited edge pixel
        let found = false;
        for (let d = 0; d < 8; d++) {
          const nx = x + dx[d];
          const ny = y + dy[d];
          if (nx >= 0 && nx < width && ny >= 0 && ny < height &&
              edges[ny]?.[nx] && !visited[ny]?.[nx]) {
            x = nx;
            y = ny;
            found = true;
            break;
          }
        }

        if (!found) break;
      }

      // Only keep paths with enough pixels
      if (pathPixels.length >= 4) {
        // Sample every Nth pixel to reduce noise and improve performance
        const sampleRate = Math.max(1, Math.floor(pathPixels.length / 100));
        const sampledPoints: Point[] = [];
        for (let i = 0; i < pathPixels.length; i += sampleRate) {
          const px = pathPixels[i];
          if (!px) continue;
          sampledPoints.push(pixelToResource(px.x, px.y));
        }
        // Always include last point
        if (pathPixels.length > 0) {
          const last = pathPixels[pathPixels.length - 1];
          if (last) {
            const lastPoint = pixelToResource(last.x, last.y);
            if (sampledPoints.length > 0) {
              const prevLast = sampledPoints[sampledPoints.length - 1];
              if (prevLast && (prevLast.x !== lastPoint.x || prevLast.y !== lastPoint.y)) {
                sampledPoints.push(lastPoint);
              }
            }
          }
        }
        
        if (sampledPoints.length >= 2) {
          paths.push({
            name: `traced_${paths.length}`,
            intensity: 127,
            closed: false,
            points: sampledPoints,
          });
        }
      }
    }
  }

  return paths;
}

/**
 * Simplify a path using Ramer-Douglas-Peucker algorithm
 */
function simplifyPath(points: Point[], tolerance: number): Point[] {
  if (points.length <= 2) return points;

  // Find the point with the maximum distance
  let maxDist = 0;
  let maxIdx = 0;
  const start = points[0];
  const end = points.length > 0 ? points[points.length - 1] : start;

  for (let i = 1; i < points.length - 1; i++) {
    const pt = points[i];
    if (!pt) continue;
    const dist = perpendicularDistance(pt, start, end);
    if (dist > maxDist) {
      maxDist = dist;
      maxIdx = i;
    }
  }

  // If max distance is greater than tolerance, recursively simplify
  if (maxDist > tolerance) {
    const left = simplifyPath(points.slice(0, maxIdx + 1), tolerance);
    const right = simplifyPath(points.slice(maxIdx), tolerance);
    return [...left.slice(0, -1), ...right];
  } else {
    // Solo devolver puntos definidos
    return [start, end].filter(Boolean) as Point[];
  }
}

function perpendicularDistance(point: Point, lineStart: Point, lineEnd: Point): number {
  const dx = lineEnd.x - lineStart.x;
  const dy = lineEnd.y - lineStart.y;
  const len = Math.sqrt(dx * dx + dy * dy);
  
  if (len === 0) {
    return Math.sqrt((point.x - lineStart.x) ** 2 + (point.y - lineStart.y) ** 2);
  }
  
  return Math.abs(
    (dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x) / len
  );
}

/**
 * Detect edges in an image and convert to vector paths
 * Uses Canny-like algorithm: Blur -> Sobel -> NMS -> Hysteresis -> Trace
 */
function detectEdgesFromImage(
  img: HTMLImageElement,
  canvasWidth: number,
  canvasHeight: number,
  resourceWidth: number,
  resourceHeight: number,
  options: EdgeDetectionOptions = defaultEdgeOptions
): VecPath[] {
  // Calculate image draw position (same as in the draw function)
  if (!img.width || !img.height) return [];
  // Image is stretched to fill 100% of the canvas area
  const drawWidth = canvasWidth;
  const drawHeight = canvasHeight;
  const drawX = 0;
  const drawY = 0;

  // Process at a reasonable resolution for speed (match canvas aspect ratio)
  const processWidth = Math.min(400, img.width);
  const processHeight = Math.round(processWidth * canvasHeight / canvasWidth);
  
  // Create a temporary canvas to process the image
  const tempCanvas = document.createElement('canvas');
  tempCanvas.width = processWidth;
  tempCanvas.height = processHeight;
  const ctx = tempCanvas.getContext('2d')!;
  
  // Draw image to processing canvas
  ctx.drawImage(img, 0, 0, processWidth, processHeight);
  
  // Get image data
  let imageData = ctx.getImageData(0, 0, processWidth, processHeight);
  
  // Step 1: Optional Gaussian blur for noise reduction (skip for thin lines/pixel art)
  if (options.useBlur) {
    imageData = gaussianBlur(imageData);
  }
  
  // Step 2: Sobel edge detection with gradient direction
  const { magnitude, direction, width, height } = sobelEdgeDetection(imageData);
  
  // Step 3: Non-Maximum Suppression - thin edges to 1 pixel
  const thinMagnitude = nonMaximumSuppression(magnitude, direction, width, height);
  
  // Step 4: Double threshold and hysteresis
  const edges = hysteresisThreshold(thinMagnitude, width, height, options.lowThreshold, options.highThreshold);
  
  // Step 5: Trace edges to paths with correct coordinate mapping
  let paths = traceEdgesToPaths(
    edges, 
    processWidth, 
    processHeight, 
    drawX, 
    drawY, 
    drawWidth, 
    drawHeight,
    canvasWidth, 
    canvasHeight, 
    resourceWidth, 
    resourceHeight
  );
  
  // Step 6: Simplify paths
  paths = paths.map(path => ({
    ...path,
    points: simplifyPath(path.points, options.simplifyTolerance),
  }));
  
  // Step 7: Filter out short paths
  paths = paths.filter(path => path.points.length >= options.minPathLength);
  
  return paths;
}

// ============================================
// Collision Mesh Helpers
// ============================================

function filterTopEdges(segs: CollisionSegment[]): CollisionSegment[] {
  return segs.filter(seg => {
    const xa = Math.min(seg.x1, seg.x2);
    const xb = Math.max(seg.x1, seg.x2);
    return !segs.some(t =>
      t !== seg &&
      t.y1 > seg.y1 &&
      Math.min(t.x1, t.x2) < xb &&
      Math.max(t.x1, t.x2) > xa
    );
  });
}

function generateMeshFromPath(path: VecPath): CollisionSegment[] {
  const pts = path.points;
  if (pts.length < 2) return [];
  const horiz: CollisionSegment[] = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const p1 = pts[i], p2 = pts[i + 1];
    if (!p1 || !p2) continue;
    if (p1.y === p2.y) {
      horiz.push({ x1: Math.min(p1.x, p2.x), y1: p1.y, x2: Math.max(p1.x, p2.x), y2: p2.y });
    }
  }
  if (path.closed && pts.length >= 2) {
    const p1 = pts[pts.length - 1], p2 = pts[0];
    if (p1 && p2 && p1.y === p2.y) {
      horiz.push({ x1: Math.min(p1.x, p2.x), y1: p1.y, x2: Math.max(p1.x, p2.x), y2: p2.y });
    }
  }
  return filterTopEdges(horiz);
}

// ============================================
// Main VectorEditor Component
// ============================================

export const VectorEditor: React.FC<VectorEditorProps> = ({
  resource: initialResource,
  onChange,
  width: propWidth = 480,
  height: propHeight = 640,
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const canvasContainerRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const dxfInputRef = useRef<HTMLInputElement>(null);
  const objInputRef = useRef<HTMLInputElement>(null);
  const mousePenPosRef = useRef<{ x: number; y: number } | null>(null);
  const circlePreviewRef = useRef<{ center: { x: number; y: number }; radius: number; tool: string } | null>(null);
  // Nearest vertex to the current mouse position (for hover highlight & pen snapping)
  const hoveredVertexRef = useRef<{ point: Point; canvasX: number; canvasY: number } | null>(null);
  // Nearest segment to cursor for point insertion (select mode only)
  const hoveredSegmentRef = useRef<{ pathIdx: number; segIdx: number; canvasX: number; canvasY: number; resPoint: Point } | null>(null);

  // Dynamic canvas size — updated by ResizeObserver; all coordinate logic reads these
  const [width, setWidth] = useState(propWidth);
  const [height, setHeight] = useState(propHeight);
  
  // Calculate center point from all vector points (design-time)
  const calculateCenter = (res: VecResource): { centerX: number; centerY: number } => {
    const allPoints: Point[] = [];
    
    // Collect all points from all visible layers and paths
    for (const layer of res.layers || []) {
      if (!layer || !layer.visible) continue;
      for (const path of layer.paths || []) {
        if (!path || !Array.isArray(path.points)) continue;
        allPoints.push(...path.points);
      }
    }
    
    if (allPoints.length === 0) {
      return { centerX: 0, centerY: 0 };
    }
    
    // Calculate min/max for X and Y
    let minX = allPoints[0]!.x;
    let maxX = allPoints[0]!.x;
    let minY = allPoints[0]!.y;
    let maxY = allPoints[0]!.y;
    
    for (const point of allPoints) {
      minX = Math.min(minX, point.x);
      maxX = Math.max(maxX, point.x);
      minY = Math.min(minY, point.y);
      maxY = Math.max(maxY, point.y);
    }
    
    // Center = (min + max) / 2
    return {
      centerX: (minX + maxX) / 2,
      centerY: (minY + maxY) / 2,
    };
  };
  
  // Ensure resource has valid structure with visible layers
  const normalizeResource = (res: VecResource | undefined): VecResource => {
    if (!res) return defaultResource;
    const normalized = { ...res };
    // Ensure layers array exists
    if (!normalized.layers || normalized.layers.length === 0) {
      normalized.layers = [{ name: 'drawing', visible: true, paths: [] }];
    } else {
      // Ensure all layers have visible property
      normalized.layers = normalized.layers.map(layer => ({
        ...layer,
        visible: layer.visible !== false, // default to true
      }));
    }
    
    // Calculate and add center if not present
    if (normalized.center_x === undefined || normalized.center_y === undefined) {
      const { centerX, centerY } = calculateCenter(normalized);
      normalized.center_x = Math.round(centerX);
      normalized.center_y = Math.round(centerY);
    }
    
    return normalized;
  };
  
  const [resource, setResource] = useState<VecResource>(() => normalizeResource(initialResource));
  const [currentTool, setCurrentTool] = useState<Tool>('select');
  const [currentLayerIndex, setCurrentLayerIndex] = useState(0);
  const [currentPathIndex, setCurrentPathIndex] = useState(-1);
  const [selectedPointIndex, setSelectedPointIndex] = useState(-1);
  const [selectedPoints, setSelectedPoints] = useState<Set<string>>(new Set()); // "pathIdx-pointIdx" format
  // Tree panel selection: "layerIdx-pathIdx" key, or null
  const [selectedTreePathKey, setSelectedTreePathKey] = useState<string | null>(null);
  // Multi-selection of paths in tree: Set of "layerIdx-pathIdx" keys
  const [selectedTreePathKeys, setSelectedTreePathKeys] = useState<Set<string>>(new Set());
  // Intensity text input value for "Set Intensity" feature
  const [setIntensityInput, setSetIntensityInput] = useState<string>('127');
  // Which paths are expanded in the tree to show individual points: "layerIdx-pathIdx" keys
  const [expandedTreePaths, setExpandedTreePaths] = useState<Set<string>>(new Set());
  // Which layers have their path list collapsed (default: expanded)
  const [collapsedLayerPaths, setCollapsedLayerPaths] = useState<Set<number>>(new Set());
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [viewMode, setViewMode] = useState<ViewMode>('xy');
  const [rotation3D, setRotation3D] = useState({ pitch: 30, yaw: 45 }); // degrees
  const [isDrawing, setIsDrawing] = useState(false);
  const [tempPoints, setTempPoints] = useState<Point[]>([]);
  const [showCollisionMesh, setShowCollisionMesh] = useState(false);
  const [selectedEdge, setSelectedEdge] = useState<{ pathIdx: number; edgeIdx: number } | null>(null);
  // Walkable-area paint state (active when currentTool === 'walkarea').
  const walkAreaDrawStartRef = useRef<{ x: number; y: number } | null>(null);
  const [walkAreaPreview, setWalkAreaPreview] = useState<{ y: number; x_min: number; x_max: number } | null>(null);

  // Tracks the mousedown position for bezier anchor drag detection
  const bezierMouseDownRef = useRef<{ canvasX: number; canvasY: number; resPoint: Point } | null>(null);

  // Circle/Arc/Polygon tool settings
  const [circleSegments, setCircleSegments] = useState(16);
  const [arcStartAngle, setArcStartAngle] = useState(0);
  const [arcEndAngle, setArcEndAngle] = useState(180);
  const [circleCenter, setCircleCenter] = useState<Point | null>(null);
  const [circleRadius, setCircleRadius] = useState(0);
  const [polygonSides, setPolygonSides] = useState(6);
  
  // Undo/Redo history
  const [history, setHistory] = useState<VecResource[]>([]);
  const [historyIndex, setHistoryIndex] = useState(-1);

  // 3D import dialog state (shared by DXF and OBJ)
  interface RawPath { pts: Point[]; closed: boolean }
  interface ObjEdge {
    a: number; b: number; dot: number; border: boolean;
    n1?: Vec3; n2?: Vec3; // face normals (only for shared edges, used for silhouette mode)
  }
  interface ImportDialogState {
    source: 'DXF' | 'OBJ';
    rawPaths: RawPath[];
    bbox: { minX: number; maxX: number; minY: number; maxY: number; minZ: number; maxZ: number };
    referencePlane: 'xy' | 'xz' | 'yz' | 'manual';
    manualScale: number;
    // OBJ-only: raw edge data for re-filtering when angle threshold changes
    objVerts?: [number, number, number][];
    objEdges?: ObjEdge[];
    angleThreshold?: number; // degrees, default 25
    edgeMode?: 'hard' | 'silhouette'; // default 'hard'
  }
  const [dxfImport, setDxfImport] = useState<ImportDialogState | null>(null);

  // Re-chain OBJ hard edges into RawPaths given a set of (a,b) pairs and vertex array
  const chainObjEdges = (hardEdges: [number, number][], verts: [number, number, number][]): RawPath[] => {
    const adj = new Map<number, number[]>();
    const edgeDegree = new Map<number, number>();
    for (const [a, b] of hardEdges) {
      edgeDegree.set(a, (edgeDegree.get(a) ?? 0) + 1);
      edgeDegree.set(b, (edgeDegree.get(b) ?? 0) + 1);
    }
    for (const [a, b] of hardEdges) {
      if (!adj.has(a)) adj.set(a, []);
      if (!adj.has(b)) adj.set(b, []);
      adj.get(a)!.push(b);
      adj.get(b)!.push(a);
    }
    const usedEdges = new Set<string>();
    const edgeKey = (a: number, b: number) => `${Math.min(a,b)},${Math.max(a,b)}`;
    const result: RawPath[] = [];
    const walkChain = (start: number, firstNext: number) => {
      const chain: number[] = [start, firstNext];
      usedEdges.add(edgeKey(start, firstNext));
      let cur = firstNext, prev = start;
      while (true) {
        const neighbors = adj.get(cur) ?? [];
        const nextCandidates = neighbors.filter(n => n !== prev && !usedEdges.has(edgeKey(cur, n)));
        if (nextCandidates.length === 1 && (edgeDegree.get(cur) ?? 0) === 2) {
          const next = nextCandidates[0];
          usedEdges.add(edgeKey(cur, next));
          chain.push(next); prev = cur; cur = next;
        } else break;
      }
      const closed = chain[0] === chain[chain.length - 1];
      result.push({ pts: chain.map(v => ({ x: verts[v][0], y: verts[v][1], z: verts[v][2] })), closed });
    };
    const startVerts = [...edgeDegree.entries()].filter(([, d]) => d !== 2).map(([v]) => v);
    for (const sv of startVerts)
      for (const nb of (adj.get(sv) ?? []))
        if (!usedEdges.has(edgeKey(sv, nb))) walkChain(sv, nb);
    for (const v of [...edgeDegree.keys()])
      for (const nb of (adj.get(v) ?? []))
        if (!usedEdges.has(edgeKey(v, nb))) walkChain(v, nb);
    return result;
  };

  // Compute silhouette edges for a given view direction.
  // A silhouette edge = border (only 1 face) OR the two face normals straddle the view plane
  // i.e. (n1·viewDir) * (n2·viewDir) <= 0
  type Vec3 = [number, number, number];
  const viewDirForPlane = (plane: 'xy' | 'xz' | 'yz' | 'manual'): Vec3 =>
    plane === 'yz' ? [1, 0, 0] : plane === 'xz' ? [0, 1, 0] : [0, 0, 1];

  const silhouetteEdges = (edges: ObjEdge[], plane: 'xy' | 'xz' | 'yz' | 'manual'): [number, number][] => {
    const [vx, vy, vz] = viewDirForPlane(plane);
    return edges
      .filter(e => {
        if (e.border || !e.n2) return true; // border always visible
        const d1 = e.n1![0] * vx + e.n1![1] * vy + e.n1![2] * vz;
        const d2 = e.n2[0] * vx + e.n2[1] * vy + e.n2[2] * vz;
        return d1 * d2 <= 0; // sign change → silhouette
      })
      .map(e => [e.a, e.b]);
  };

  // Track if we're the source of changes to avoid loops
  const isInternalChange = useRef(false);
  
  // Sync with external resource changes (but not our own changes)
  // Resize the canvas to the largest square that fits the available space
  useEffect(() => {
    const el = canvasContainerRef.current;
    if (!el) return;
    const obs = new ResizeObserver(([entry]) => {
      const { width: cw, height: ch } = entry.contentRect;
      if (cw > 20 && ch > 20) {
        const size = Math.min(Math.floor(cw), Math.floor(ch));
        setWidth(size);
        setHeight(size);
      }
    });
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  useEffect(() => {
    if (isInternalChange.current) {
      isInternalChange.current = false;
      return;
    }
    if (initialResource) {
      const normalized = normalizeResource(initialResource);
      const pointsCount = normalized.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
      console.log('[VectorEditor] LOAD: Initializing from resource with', pointsCount, 'points');
      console.log('[VectorEditor] LOAD: Setting history to:', [normalized]);
      setResource(normalized);
      // Initialize history with the loaded resource - THIS MUST PERSIST
      setHistory([normalized]);
      setHistoryIndex(0);
    }
  }, [initialResource]);
  
  // Wrapper to set resource and notify parent
  // IMPORTANT: Takes the PREVIOUS resource as first parameter to save to history
  const updateResource = useCallback((previousResource: VecResource, newResource: VecResource) => {
    // Recalculate center whenever resource changes
    const { centerX, centerY } = calculateCenter(newResource);
    const withCenter = {
      ...newResource,
      center_x: Math.round(centerX),
      center_y: Math.round(centerY),
    };
    const previousPointsCount = previousResource.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
    const newPointsCount = withCenter.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
    
    // IMPORTANT: Save the PREVIOUS resource to history, not the new state
    setHistory(prev => {
      // Properly handle redo history: if we're not at the end of history, truncate
      const truncatedHistory = prev.slice(0, historyIndex + 1);
      // Save the PREVIOUS resource with its center
      const { centerX, centerY } = calculateCenter(previousResource);
      const previousWithCenter = {
        ...previousResource,
        center_x: Math.round(centerX),
        center_y: Math.round(centerY),
      };
      const newHistory = [...truncatedHistory, previousWithCenter];
      console.log('[VectorEditor] UPDATE_RESOURCE: Saving', previousPointsCount, 'points', 
                  '| New state has', newPointsCount, 'points',
                  '| History:', prev.length, '→', newHistory.length);
      return newHistory;
    });
    
    setHistoryIndex(prev => prev + 1);
    
    isInternalChange.current = true; // Set flag BEFORE changing state
    setResource(withCenter);
    onChange?.(withCenter);
  }, [onChange, historyIndex]);

  // Undo: go back one step in history
  const handleUndo = useCallback(() => {
    if (historyIndex > 0) {
      const newIndex = historyIndex - 1;
      const previousState = history[newIndex];
      const pointsBefore = resource.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
      const pointsInHistory = previousState.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
      
      // Log entire history state
      const historyPointsPerIndex = history.map((h, idx) => {
        const pts = h.layers[0].paths.reduce((sum, p) => sum + p.points.length, 0);
        return `[${idx}]:${pts}`;
      }).join(' ');
      
      console.log('[VectorEditor] UNDO: From index', historyIndex, 'to', newIndex);
      console.log('[VectorEditor] UNDO: Current points:', pointsBefore, '→ Will restore:', pointsInHistory);
      console.log('[VectorEditor] UNDO: Full history:', historyPointsPerIndex);
      setHistoryIndex(newIndex);
      setResource(previousState);
      // Don't call onChange - undo is local only, no need to notify parent
    }
  }, [history, historyIndex, resource]);

  // Redo: go forward one step in history
  const handleRedo = useCallback(() => {
    if (historyIndex < history.length - 1) {
      const newIndex = historyIndex + 1;
      const nextState = history[newIndex];
      setHistoryIndex(newIndex);
      setResource(nextState);
      // Don't call onChange - redo is local only, no need to notify parent
    }
  }, [history, historyIndex]);

  // Scale all points by a factor
  const handleScale = (factor: number) => {
    const scaled = JSON.parse(JSON.stringify(resource)) as VecResource;
    let pointsScaled = 0;
    
    for (const layer of scaled.layers) {
      if (Array.isArray(layer.paths)) {
        for (const path of layer.paths) {
          if (Array.isArray(path.points)) {
            for (const point of path.points) {
              point.x = Math.round(point.x * factor);
              point.y = Math.round(point.y * factor);
              if (point.z) point.z = Math.round(point.z * factor);
              pointsScaled++;
            }
          }
        }
      }
    }
    
    // Scale background offset proportionally
    if (scaled.backgroundOffset) {
      scaled.backgroundOffset = {
        x: Math.round(scaled.backgroundOffset.x * factor),
        y: Math.round(scaled.backgroundOffset.y * factor),
      };
      setBackgroundOffset(scaled.backgroundOffset);
    }

    console.log('[VectorEditor] Scaled', pointsScaled, 'points with factor', factor);
    updateResource(resource, scaled);
  };
  
  // Box selection state
  const [isBoxSelecting, setIsBoxSelecting] = useState(false);
  const [boxStart, setBoxStart] = useState<{ x: number; y: number } | null>(null);
  const [boxEnd, setBoxEnd] = useState<{ x: number; y: number } | null>(null);

  // Subtract selection mode (Shift+drag box = remove from selection)
  const [isSubtractSelect, setIsSubtractSelect] = useState(false);

  // Move mode toggle (M key — drag from empty space to move all selected points)
  const [isMoveMode, setIsMoveMode] = useState(false);

  // Multi-point drag: snapshot positions at mouseDown, apply delta each frame
  const dragStartPositionsRef = useRef<Map<string, { x: number; y: number }> | null>(null);
  const dragStartResCoordRef = useRef<{ x: number; y: number } | null>(null);
  
  // Render a bezier path on a canvas context using bezierCurveTo.
  // Points layout: A0, C0_out, C1_in, A1, C1_out, C2_in, A2, ...
  const renderBezierPath = (pts: Point[], ctx2: CanvasRenderingContext2D) => {
    if (pts.length < 4) return;
    const sp = resourceToCanvas(pts[0]);
    ctx2.moveTo(sp.x, sp.y);
    for (let i = 0; i + 3 < pts.length; i += 3) {
      const cp1 = resourceToCanvas(pts[i + 1]);
      const cp2 = resourceToCanvas(pts[i + 2]);
      const ep  = resourceToCanvas(pts[i + 3]);
      ctx2.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, ep.x, ep.y);
    }
  };

  // Draw handle lines + handle dots for a bezier path (shows control tangents).
  const drawBezierHandles = (pts: Point[], ctx2: CanvasRenderingContext2D) => {
    ctx2.save();
    ctx2.strokeStyle = 'rgba(255,255,255,0.35)';
    ctx2.lineWidth = 1;
    ctx2.setLineDash([3, 3]);
    // For each anchor at 3k: draw line to pts[3k-1] (cp_in, if exists) and pts[3k+1] (cp_out, if exists)
    for (let k = 0; k * 3 < pts.length; k++) {
      const ai = k * 3;
      const ac = resourceToCanvas(pts[ai]);
      const cpOutIdx = ai + 1;
      const cpInIdx  = ai - 1;
      if (cpOutIdx < pts.length) {
        const cpOut = resourceToCanvas(pts[cpOutIdx]);
        ctx2.beginPath();
        ctx2.moveTo(ac.x, ac.y);
        ctx2.lineTo(cpOut.x, cpOut.y);
        ctx2.stroke();
        ctx2.setLineDash([]);
        ctx2.fillStyle = '#ffffff';
        ctx2.beginPath();
        ctx2.arc(cpOut.x, cpOut.y, 3, 0, Math.PI * 2);
        ctx2.fill();
        ctx2.setLineDash([3, 3]);
      }
      if (cpInIdx >= 0) {
        const cpIn = resourceToCanvas(pts[cpInIdx]);
        ctx2.beginPath();
        ctx2.moveTo(ac.x, ac.y);
        ctx2.lineTo(cpIn.x, cpIn.y);
        ctx2.stroke();
        ctx2.setLineDash([]);
        ctx2.fillStyle = '#ffffff';
        ctx2.beginPath();
        ctx2.arc(cpIn.x, cpIn.y, 3, 0, Math.PI * 2);
        ctx2.fill();
        ctx2.setLineDash([3, 3]);
      }
    }
    ctx2.restore();
  };

  // Helper functions for circle/arc generation
  const generateCirclePoints = (center: Point, radius: number, segments: number, closed: boolean = true): Point[] => {
    const points: Point[] = [];
    const angleStep = (Math.PI * 2) / segments;
    
    for (let i = 0; i < (closed ? segments : segments + 1); i++) {
      const angle = i * angleStep;
      points.push({
        x: Math.round(center.x + Math.cos(angle) * radius),
        y: Math.round(center.y + Math.sin(angle) * radius),
      });
    }
    
    return points;
  };
  
  const generatePolygonPoints = (center: Point, radius: number, sides: number): Point[] => {
    const points: Point[] = [];
    const angleStep = (Math.PI * 2) / sides;
    // Start from top (-PI/2) so flat edge is at bottom for even sided polygons
    const startAngle = -Math.PI / 2;
    for (let i = 0; i < sides; i++) {
      const angle = startAngle + i * angleStep;
      points.push({
        x: Math.round(center.x + Math.cos(angle) * radius),
        y: Math.round(center.y + Math.sin(angle) * radius),
      });
    }
    // Close: add first point again
    points.push({ ...points[0] });
    return points;
  };

  const generateArcPoints = (center: Point, radius: number, startAngle: number, endAngle: number, segments: number): Point[] => {
    const points: Point[] = [];
    const startRad = (startAngle * Math.PI) / 180;
    const endRad = (endAngle * Math.PI) / 180;
    let angleDiff = endRad - startRad;
    
    // Normalize angle difference to 0-2π range
    while (angleDiff < 0) angleDiff += Math.PI * 2;
    while (angleDiff > Math.PI * 2) angleDiff -= Math.PI * 2;
    
    const angleStep = angleDiff / segments;
    
    for (let i = 0; i <= segments; i++) {
      const angle = startRad + i * angleStep;
      points.push({
        x: Math.round(center.x + Math.cos(angle) * radius),
        y: Math.round(center.y + Math.sin(angle) * radius),
      });
    }
    
    return points;
  };
  
  // Background image state
  const [backgroundImage, setBackgroundImage] = useState<HTMLImageElement | null>(null);
  const [backgroundOpacity, setBackgroundOpacity] = useState(0.5);
  const [showBackground, setShowBackground] = useState(true);
  const [backgroundOffset, setBackgroundOffset] = useState({ x: 0, y: 0 });
  const [isBackgroundSelected, setIsBackgroundSelected] = useState(false);
  
  // Edge detection settings
  const [edgeOptions, setEdgeOptions] = useState<EdgeDetectionOptions>(defaultEdgeOptions);
  const [showEdgeSettings, setShowEdgeSettings] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [previewPaths, setPreviewPaths] = useState<VecPath[]>([]); // Preview paths before applying
  const [showPreview, setShowPreview] = useState(true);
  const previewTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  
  // Mouse coordinates in Vectrex space
  const [mouseVectrexCoords, setMouseVectrexCoords] = useState<{ x: number; y: number } | null>(null);

  // Generate preview when edge settings change
  useEffect(() => {
    if (!showEdgeSettings || !backgroundImage) {
      setPreviewPaths([]);
      return;
    }
    
    // Debounce the preview generation
    if (previewTimeoutRef.current) {
      clearTimeout(previewTimeoutRef.current);
    }
    
    previewTimeoutRef.current = setTimeout(() => {
      try {
        const paths = detectEdgesFromImage(
          backgroundImage,
          width,
          height,
          resource.canvas.width,
          resource.canvas.height,
          edgeOptions
        );
        setPreviewPaths(paths);
      } catch (error) {
        console.error('Preview generation failed:', error);
        setPreviewPaths([]);
      }
    }, 150); // 150ms debounce
    
    return () => {
      if (previewTimeoutRef.current) {
        clearTimeout(previewTimeoutRef.current);
      }
    };
  }, [edgeOptions, backgroundImage, showEdgeSettings, width, height, resource.canvas.width, resource.canvas.height]);

  // Convert canvas coordinates to resource coordinates (2D projection)
  const canvasToResource = useCallback((canvasX: number, canvasY: number): Point => {
    const centerX = width / 2;
    const centerY = height / 2;
    const scale = Math.min(width, height) / resource.canvas.width;
    
    const x = (canvasX - centerX - pan.x) / (scale * zoom);
    const y = (centerY - canvasY + pan.y) / (scale * zoom);
    
    // For 3D views, we need to consider which plane we're drawing on
    if (viewMode === 'xy') {
      return { x: Math.round(x), y: Math.round(y), z: 0 };
    } else if (viewMode === 'xz') {
      return { x: Math.round(x), y: 0, z: Math.round(y) };
    } else if (viewMode === 'yz') {
      return { x: 0, y: Math.round(x), z: Math.round(y) };
    } else {
      // 3D view - not editable directly
      return { x: Math.round(x), y: Math.round(y), z: 0 };
    }
  }, [width, height, resource.canvas.width, pan, zoom, viewMode]);

  // Project 3D point to 2D based on current view
  const project3DTo2D = useCallback((point: Point): { x: number; y: number; z: number } => {
    const x = point.x || 0;
    const y = point.y || 0;
    const z = point.z || 0;
    
    if (viewMode === 'xy') {
      return { x, y, z: 0 };
    } else if (viewMode === 'xz') {
      return { x, y: z, z: 0 };
    } else if (viewMode === 'yz') {
      return { x: y, y: z, z: 0 };
    } else { // 3D perspective
      const pitch = (rotation3D.pitch * Math.PI) / 180;
      const yaw = (rotation3D.yaw * Math.PI) / 180;

      // Rotate around Y axis (yaw)
      const x1 = x * Math.cos(yaw) - z * Math.sin(yaw);
      const z1 = x * Math.sin(yaw) + z * Math.cos(yaw);

      // Rotate around X axis (pitch)
      const y2 = y * Math.cos(pitch) - z1 * Math.sin(pitch);
      const z2 = y * Math.sin(pitch) + z1 * Math.cos(pitch);

      // Orthographic projection — z2 is depth (smaller = closer to viewer)
      return { x: x1, y: y2, z: z2 };
    }
  }, [viewMode, rotation3D]);
  
  // Convert resource coordinates to canvas coordinates
  const resourceToCanvas = useCallback((point: Point): { x: number; y: number } => {
    const centerX = width / 2;
    const centerY = height / 2;
    const scale = Math.min(width, height) / resource.canvas.width;
    
    const projected = project3DTo2D(point);
    
    return {
      x: centerX + projected.x * scale * zoom + pan.x,
      y: centerY - projected.y * scale * zoom + pan.y,
    };
  }, [width, height, resource.canvas.width, pan, zoom, project3DTo2D]);

  // Like resourceToCanvas but also returns z depth (for 3D hit-testing)
  const resourceToCanvasWithDepth = useCallback((point: Point): { x: number; y: number; z: number } => {
    const centerX = width / 2;
    const centerY = height / 2;
    const scale = Math.min(width, height) / resource.canvas.width;
    const projected = project3DTo2D(point);
    return {
      x: centerX + projected.x * scale * zoom + pan.x,
      y: centerY - projected.y * scale * zoom + pan.y,
      z: projected.z,
    };
  }, [width, height, resource.canvas.width, pan, zoom, project3DTo2D]);

  // Find the nearest vertex (across all layers) within snapRadius canvas pixels.
  // Returns the 3D resource point and its projected canvas position, or null.
  const findNearestVertex = useCallback((canvasX: number, canvasY: number, snapRadius = 14): { point: Point; canvasX: number; canvasY: number } | null => {
    let best: { point: Point; canvasX: number; canvasY: number } | null = null;
    let bestDist = snapRadius;
    let bestZ = Infinity;

    for (const layer of resource.layers) {
      if (!layer || !layer.visible || !Array.isArray(layer.paths)) continue;
      for (const path of layer.paths) {
        if (!path || !Array.isArray(path.points)) continue;
        for (const pt of path.points) {
          if (!pt) continue;
          const c = resourceToCanvasWithDepth(pt);
          const dist = Math.sqrt((c.x - canvasX) ** 2 + (c.y - canvasY) ** 2);
          if (dist < snapRadius) {
            const betterDist = dist < bestDist - 0.5;
            const sameDist = Math.abs(dist - bestDist) <= 0.5;
            if (betterDist || (sameDist && c.z < bestZ)) {
              bestDist = dist;
              bestZ = c.z;
              best = { point: pt, canvasX: c.x, canvasY: c.y };
            }
          }
        }
      }
    }
    return best;
  }, [resource, resourceToCanvasWithDepth]);

  // Helper function to calculate distance from point to line segment
  const pointToLineDistance = (px: number, py: number, x1: number, y1: number, x2: number, y2: number): number => {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len === 0) return Math.sqrt((px - x1) ** 2 + (py - y1) ** 2);

    let t = ((px - x1) * dx + (py - y1) * dy) / (len * len);
    t = Math.max(0, Math.min(1, t));

    const closestX = x1 + t * dx;
    const closestY = y1 + t * dy;

    return Math.sqrt((px - closestX) ** 2 + (py - closestY) ** 2);
  };

  // Returns the projected canvas point and t parameter on a segment, or null if beyond endpoints
  const projectOnSegment = (px: number, py: number, x1: number, y1: number, x2: number, y2: number): { canvasX: number; canvasY: number; t: number; dist: number } | null => {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const lenSq = dx * dx + dy * dy;
    if (lenSq === 0) return null;
    let t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
    t = Math.max(0.01, Math.min(0.99, t)); // exclude endpoints
    const cx = x1 + t * dx;
    const cy = y1 + t * dy;
    const dist = Math.sqrt((px - cx) ** 2 + (py - cy) ** 2);
    return { canvasX: cx, canvasY: cy, t, dist };
  };

  // Draw the canvas
  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Clear
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, width, height);

    // Draw background image if present
    if (backgroundImage && showBackground) {
      ctx.save();
      ctx.globalAlpha = backgroundOpacity;

      // Fit image inside the Vectrex screen rect (3:4 portrait, object-fit: contain)
      const screenL = resourceToCanvas({ x: -96, y: 0 });
      const screenR = resourceToCanvas({ x: 95, y: 0 });
      const screenT = resourceToCanvas({ x: 0, y: 127 });
      const screenB = resourceToCanvas({ x: 0, y: -128 });
      const rectX = screenL.x + backgroundOffset.x;
      const rectY = screenT.y + backgroundOffset.y;
      const rectW = screenR.x - screenL.x;
      const rectH = screenB.y - screenT.y;

      // Stretch image to fill the Vectrex screen rect (same as vplay editor)
      const drawWidth = rectW;
      const drawHeight = rectH;
      const drawX = rectX;
      const drawY = rectY;

      ctx.drawImage(backgroundImage, drawX, drawY, drawWidth, drawHeight);

      // Draw selection highlight if background is selected
      if (isBackgroundSelected) {
        ctx.strokeStyle = '#00ff00';
        ctx.lineWidth = 3;
        ctx.setLineDash([4, 4]);
        ctx.strokeRect(drawX, drawY, drawWidth, drawHeight);
        ctx.setLineDash([]);
      }

      ctx.restore();
    }

    // Draw grid
    ctx.strokeStyle = '#2a2a4e';
    ctx.lineWidth = 1;
    const gridSize = 16 * zoom;
    const centerX = width / 2 + pan.x;
    const centerY = height / 2 + pan.y;
    
    for (let x = centerX % gridSize; x < width; x += gridSize) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, height);
      ctx.stroke();
    }
    for (let y = centerY % gridSize; y < height; y += gridSize) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(width, y);
      ctx.stroke();
    }

    // Draw axes with labels based on view mode
    ctx.lineWidth = 2;
    
    // X axis (red)
    ctx.strokeStyle = '#a44';
    ctx.beginPath();
    ctx.moveTo(0, centerY);
    ctx.lineTo(width, centerY);
    ctx.stroke();
    
    // Y/Z axis (green/blue depending on view)
    ctx.strokeStyle = viewMode === 'xz' || viewMode === 'yz' ? '#44a' : '#4a4';
    ctx.beginPath();
    ctx.moveTo(centerX, 0);
    ctx.lineTo(centerX, height);
    ctx.stroke();
    
    // Axis labels
    ctx.fillStyle = '#888';
    ctx.font = '12px monospace';
    const labelX = viewMode === 'yz' ? 'Y' : 'X';
    const labelY = viewMode === 'xy' ? 'Y' : 'Z';
    ctx.fillText(`+${labelX}`, width - 30, centerY - 10);
    ctx.fillText(`+${labelY}`, centerX + 10, 20);

    // Draw Vectrex screen reference (dimmed rectangle showing screen boundaries)
    if (viewMode === 'xy') {
      ctx.strokeStyle = '#555';
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]); // Dashed line
      
      // Vectrex screen: 3:4 portrait — X: -96 to +95 (192 units), Y: -128 to +127 (256 units)
      const screenLeft = resourceToCanvas({ x: -96, y: 0 });
      const screenRight = resourceToCanvas({ x: 95, y: 0 });
      const screenTop = resourceToCanvas({ x: 0, y: 127 });
      const screenBottom = resourceToCanvas({ x: 0, y: -128 });
      
      ctx.beginPath();
      ctx.rect(
        screenLeft.x,
        screenTop.y,
        screenRight.x - screenLeft.x,
        screenBottom.y - screenTop.y
      );
      ctx.stroke();
      ctx.setLineDash([]); // Reset dash
      
      // Label
      ctx.fillStyle = '#666';
      ctx.font = '10px monospace';
      ctx.fillText('Vectrex Screen', screenLeft.x + 5, screenTop.y - 5);
    }

    // Draw paths
    for (let layerIdx = 0; layerIdx < resource.layers.length; layerIdx++) {
      const layer = resource.layers[layerIdx];
      if (!layer || !layer.visible || !Array.isArray(layer.paths)) continue;

      for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
        const path = layer.paths[pathIdx];
        if (!path || !Array.isArray(path.points) || path.points.length < 2) continue;

        const intensity = path.intensity / 127;
        const green = Math.floor(200 + 55 * intensity);
        ctx.strokeStyle = `rgb(${Math.floor(100 * intensity)}, ${green}, ${Math.floor(100 * intensity)})`;
        ctx.lineWidth = 2;

        ctx.beginPath();
        if (path.type === 'bezier') {
          renderBezierPath(path.points, ctx);
        } else {
          const startPt = path.points[0];
          if (!startPt) continue;
          const start = resourceToCanvas(startPt);
          ctx.moveTo(start.x, start.y);
          for (let i = 1; i < path.points.length; i++) {
            const pt = path.points[i];
            if (!pt) continue;
            const ptCanvas = resourceToCanvas(pt);
            ctx.lineTo(ptCanvas.x, ptCanvas.y);
          }
          if (path.closed) ctx.closePath();
        }
        ctx.stroke();

        // For selected bezier path: draw handle lines on top
        if (path.type === 'bezier' && layerIdx === currentLayerIndex && pathIdx === currentPathIndex) {
          drawBezierHandles(path.points, ctx);
        }

        // Tree-panel selection highlight: cyan stroke override
        const treeKey = `${layerIdx}-${pathIdx}`;
        const isTreeSelected = selectedTreePathKey === treeKey;
        if (isTreeSelected) {
          ctx.strokeStyle = '#00ffff';
          ctx.lineWidth = 2.5;
          ctx.beginPath();
          if (path.type === 'bezier') {
            renderBezierPath(path.points, ctx);
          } else {
            const sp = path.points[0];
            if (sp) {
              const sc = resourceToCanvas(sp);
              ctx.moveTo(sc.x, sc.y);
              for (let i = 1; i < path.points.length; i++) {
                const pp = path.points[i];
                if (!pp) continue;
                const pc = resourceToCanvas(pp);
                ctx.lineTo(pc.x, pc.y);
              }
              if (path.closed) ctx.closePath();
            }
          }
          ctx.stroke();
        }

        if (layerIdx === currentLayerIndex && pathIdx === currentPathIndex) {
          for (let i = 0; i < path.points.length; i++) {
            const pt = path.points[i];
            if (!pt) continue;
            const ptCanvas = resourceToCanvas(pt);
            const isSelected = selectedPoints.has(`${pathIdx}-${i}`);
            const isControl = path.type === 'bezier' && pt.t === 'c';
            if (isControl) {
              // Control points: small cyan squares
              ctx.fillStyle = isSelected ? '#ff6600' : 'rgba(0,200,255,0.7)';
              const s = 3;
              ctx.fillRect(ptCanvas.x - s, ptCanvas.y - s, s * 2, s * 2);
            } else {
              ctx.fillStyle = isSelected ? '#ff6600' : '#ffff00';
              ctx.beginPath();
              ctx.arc(ptCanvas.x, ptCanvas.y, i === selectedPointIndex || isSelected ? 6 : 4, 0, Math.PI * 2);
              ctx.fill();
            }
          }
        }
        
        // Draw selected points from multi-selection
        if (layerIdx === currentLayerIndex) {
          for (let i = 0; i < path.points.length; i++) {
            if (selectedPoints.has(`${pathIdx}-${i}`)) {
              const pt = path.points[i];
              if (!pt) continue;
              const ptCanvas = resourceToCanvas(pt);
              ctx.fillStyle = '#ff6600';
              ctx.beginPath();
              ctx.arc(ptCanvas.x, ptCanvas.y, 6, 0, Math.PI * 2);
              ctx.fill();
            }
          }
        }
      }
    }

    // Draw selected edge highlight (for collision mesh edge selection)
    if (selectedEdge !== null) {
      const layer = resource.layers[currentLayerIndex];
      const path = layer?.paths[selectedEdge.pathIdx];
      if (path) {
        const p1r = path.points[selectedEdge.edgeIdx];
        const p2r = path.points[selectedEdge.edgeIdx + 1];
        if (p1r && p2r) {
          const p1 = resourceToCanvas(p1r);
          const p2 = resourceToCanvas(p2r);
          ctx.save();
          ctx.strokeStyle = '#ffaa00';
          ctx.lineWidth = 3;
          ctx.setLineDash([]);
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.stroke();
          ctx.fillStyle = '#ffaa00';
          ctx.beginPath(); ctx.arc(p1.x, p1.y, 4, 0, Math.PI * 2); ctx.fill();
          ctx.beginPath(); ctx.arc(p2.x, p2.y, 4, 0, Math.PI * 2); ctx.fill();
          ctx.restore();
        }
      }
    }

    // Draw collision mesh overlay
    if (showCollisionMesh && resource.collisionMesh?.segments?.length) {
      ctx.save();
      ctx.strokeStyle = '#ff44ff';
      ctx.lineWidth = 2;
      ctx.setLineDash([4, 3]);
      for (const seg of resource.collisionMesh.segments) {
        const p1 = resourceToCanvas({ x: seg.x1, y: seg.y1 });
        const p2 = resourceToCanvas({ x: seg.x2, y: seg.y2 });
        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.stroke();
        // Small tick marks at endpoints
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.arc(p1.x, p1.y, 3, 0, Math.PI * 2);
        ctx.arc(p2.x, p2.y, 3, 0, Math.PI * 2);
        ctx.fillStyle = '#ff44ff';
        ctx.fill();
        ctx.setLineDash([4, 3]);
      }
      ctx.setLineDash([]);
      ctx.restore();
    }

    // Draw walkable areas baked into the .vec (Phase 2 wander AI). Cyan
    // dashed bars with their index, plus the live preview while painting.
    if (resource.walkableAreas?.length || walkAreaPreview) {
      ctx.save();
      ctx.strokeStyle = '#44ffcc';
      ctx.fillStyle = '#44ffcc';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 3]);
      (resource.walkableAreas ?? []).forEach((a, idx) => {
        const left  = resourceToCanvas({ x: a.x_min, y: a.y });
        const right = resourceToCanvas({ x: a.x_max, y: a.y });
        ctx.beginPath();
        ctx.moveTo(left.x, left.y);
        ctx.lineTo(right.x, right.y);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.beginPath();
        ctx.moveTo(left.x,  left.y  - 5); ctx.lineTo(left.x,  left.y  + 5);
        ctx.moveTo(right.x, right.y - 5); ctx.lineTo(right.x, right.y + 5);
        ctx.stroke();
        ctx.font = '11px monospace';
        ctx.textAlign = 'center';
        ctx.fillText(`W${idx}`, (left.x + right.x) / 2, left.y - 6);
        ctx.setLineDash([4, 3]);
      });
      if (walkAreaPreview) {
        const a = walkAreaPreview;
        const left  = resourceToCanvas({ x: a.x_min, y: a.y });
        const right = resourceToCanvas({ x: a.x_max, y: a.y });
        ctx.strokeStyle = '#00ffff';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(left.x, left.y);
        ctx.lineTo(right.x, right.y);
        ctx.stroke();
      }
      ctx.restore();
    }

    // Draw temporary points while drawing
    if (tempPoints.length > 0) {
      ctx.strokeStyle = '#00ffff';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 5]);
      ctx.beginPath();
      const startPt = tempPoints[0];
      if (startPt) {
        const start = resourceToCanvas(startPt);
        ctx.moveTo(start.x, start.y);
        for (let i = 1; i < tempPoints.length; i++) {
          const pt = tempPoints[i];
          if (!pt) continue;
          const ptCanvas = resourceToCanvas(pt);
          ctx.lineTo(ptCanvas.x, ptCanvas.y);
        }
      }
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#00ffff';
      for (const point of tempPoints) {
        const pt = resourceToCanvas(point);
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, 4, 0, Math.PI * 2);
        ctx.fill();
      }

      // Rubber-band: preview line from last point to current mouse position
      const lastPt = tempPoints[tempPoints.length - 1];
      if (lastPt && mousePenPosRef.current) {
        const lastCanvas = resourceToCanvas(lastPt);
        ctx.strokeStyle = '#00ffff';
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.globalAlpha = 0.6;
        ctx.beginPath();
        ctx.moveTo(lastCanvas.x, lastCanvas.y);
        ctx.lineTo(mousePenPosRef.current.x, mousePenPosRef.current.y);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;
      }
    }

    // -- Bezier tool temp-preview --
    if (currentTool === 'bezier' && tempPoints.length >= 2) {
      // Draw already-confirmed segments
      ctx.strokeStyle = '#00ccff';
      ctx.lineWidth = 2;
      ctx.setLineDash([]);
      ctx.beginPath();
      renderBezierPath(tempPoints, ctx);
      ctx.stroke();

      // Draw handle lines for confirmed anchors
      drawBezierHandles(tempPoints, ctx);

      // Rubber-band: preview segment from last confirmed anchor to mouse/pending
      const lastAnchor = tempPoints[tempPoints.length - 2]; // A_last
      const lastCpOut  = tempPoints[tempPoints.length - 1]; // C_last_out
      if (lastAnchor && lastCpOut && mousePenPosRef.current) {
        const mouseCanvas = mousePenPosRef.current;
        const mouseRes = canvasToResource(mouseCanvas.x, mouseCanvas.y);
        const md = bezierMouseDownRef.current;

        let cp2Res: Point;
        let endRes: Point;
        if (md) {
          // Dragging: symmetric handles at pending anchor
          const ddx = mouseRes.x - md.resPoint.x;
          const ddy = mouseRes.y - md.resPoint.y;
          cp2Res = { x: Math.round(md.resPoint.x - ddx), y: Math.round(md.resPoint.y - ddy) };
          endRes = md.resPoint;
          // Draw pending anchor's handles
          const pa = resourceToCanvas(md.resPoint);
          const hIn  = resourceToCanvas(cp2Res);
          const hOut = resourceToCanvas({ x: Math.round(md.resPoint.x + ddx), y: Math.round(md.resPoint.y + ddy) });
          ctx.save();
          ctx.strokeStyle = 'rgba(255,255,255,0.5)';
          ctx.lineWidth = 1;
          ctx.setLineDash([3, 3]);
          ctx.beginPath();
          ctx.moveTo(hIn.x, hIn.y); ctx.lineTo(pa.x, pa.y); ctx.lineTo(hOut.x, hOut.y);
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.fillStyle = '#ffffff';
          for (const h of [hIn, hOut]) {
            ctx.beginPath(); ctx.arc(h.x, h.y, 3, 0, Math.PI * 2); ctx.fill();
          }
          ctx.beginPath(); ctx.arc(pa.x, pa.y, 5, 0, Math.PI * 2);
          ctx.fillStyle = '#00ccff'; ctx.fill();
          ctx.restore();
        } else {
          // Just hovering: sharp-corner preview to mouse
          cp2Res = mouseRes;
          endRes = mouseRes;
        }

        const laC  = resourceToCanvas(lastAnchor);
        const cp1C = resourceToCanvas(lastCpOut);
        const cp2C = resourceToCanvas(cp2Res);
        const epC  = resourceToCanvas(endRes);
        ctx.beginPath();
        ctx.moveTo(laC.x, laC.y);
        ctx.bezierCurveTo(cp1C.x, cp1C.y, cp2C.x, cp2C.y, epC.x, epC.y);
        ctx.strokeStyle = '#00ccff';
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.globalAlpha = 0.7;
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;
      }

      // Draw anchor markers for already-confirmed points
      for (let i = 0; i < tempPoints.length; i++) {
        const pt = tempPoints[i];
        const pc = resourceToCanvas(pt);
        if (i % 3 === 0) {
          ctx.fillStyle = '#00ccff';
          ctx.beginPath(); ctx.arc(pc.x, pc.y, 5, 0, Math.PI * 2); ctx.fill();
        }
      }
    }

    // Draw circle/arc preview while dragging (reads from ref for synchronous updates)
    const circlePreview = circlePreviewRef.current;
    if (circlePreview && circlePreview.radius > 0) {
      const { center: previewCenter, radius: previewRadius, tool: previewTool } = circlePreview;
      const previewPoints = previewTool === 'circle'
        ? generateCirclePoints(previewCenter, previewRadius, circleSegments, true)
        : previewTool === 'polygon'
        ? generatePolygonPoints(previewCenter, previewRadius, polygonSides)
        : generateArcPoints(previewCenter, previewRadius, arcStartAngle, arcEndAngle, circleSegments);

      ctx.strokeStyle = '#00ff00';
      ctx.lineWidth = 2;
      ctx.setLineDash([5, 5]);
      ctx.beginPath();

      if (previewPoints.length > 0) {
        const startPt = resourceToCanvas(previewPoints[0]);
        ctx.moveTo(startPt.x, startPt.y);
        for (let i = 1; i < previewPoints.length; i++) {
          const pt = resourceToCanvas(previewPoints[i]);
          ctx.lineTo(pt.x, pt.y);
        }
        if (previewTool === 'circle' || previewTool === 'polygon') {
          ctx.closePath();
        }
      }
      ctx.stroke();
      ctx.setLineDash([]);

      // Draw center point
      const centerCanvas = resourceToCanvas(previewCenter);
      ctx.fillStyle = '#00ff00';
      ctx.beginPath();
      ctx.arc(centerCanvas.x, centerCanvas.y, 5, 0, Math.PI * 2);
      ctx.fill();

      // Draw radius line
      if (previewPoints.length > 0) {
        const firstPt = resourceToCanvas(previewPoints[0]);
        ctx.strokeStyle = '#00ff00';
        ctx.lineWidth = 1;
        ctx.setLineDash([3, 3]);
        ctx.beginPath();
        ctx.moveTo(centerCanvas.x, centerCanvas.y);
        ctx.lineTo(firstPt.x, firstPt.y);
        ctx.stroke();
        ctx.setLineDash([]);

        // Draw radius text
        ctx.fillStyle = '#00ff00';
        ctx.font = '12px monospace';
        ctx.fillText(`R: ${previewRadius}`, centerCanvas.x + 10, centerCanvas.y - 10);
      }
    }
    
    // Draw box selection rectangle
    if (isBoxSelecting && boxStart && boxEnd) {
      const selectColor = isSubtractSelect ? '#ff4444' : '#00aaff';
      ctx.strokeStyle = selectColor;
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]);
      ctx.fillStyle = isSubtractSelect ? 'rgba(255, 68, 68, 0.1)' : 'rgba(0, 170, 255, 0.1)';
      const x = Math.min(boxStart.x, boxEnd.x);
      const y = Math.min(boxStart.y, boxEnd.y);
      const w = Math.abs(boxEnd.x - boxStart.x);
      const h = Math.abs(boxEnd.y - boxStart.y);
      ctx.fillRect(x, y, w, h);
      ctx.strokeRect(x, y, w, h);
      ctx.setLineDash([]);
      // Draw +/- indicator in corner of selection box
      ctx.font = 'bold 14px monospace';
      ctx.fillStyle = selectColor;
      ctx.fillText(isSubtractSelect ? '\u2212' : '+', x + 4, y + 16);
    }

    // Draw MOVE mode indicator
    if (isMoveMode) {
      ctx.font = 'bold 11px monospace';
      ctx.fillStyle = '#ffaa00';
      ctx.fillText('MOVE', 8, 18);
    }
    
    // Draw preview paths (edge detection preview)
    if (showPreview && previewPaths.length > 0 && showEdgeSettings) {
      ctx.strokeStyle = '#ff00ff';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([3, 3]);
      ctx.globalAlpha = 0.7;
      
      for (const path of previewPaths) {
        if (path.points.length < 2) continue;
        
        ctx.beginPath();
        const startPt = path.points[0];
        if (!startPt) continue;
        const start = resourceToCanvas(startPt);
        ctx.moveTo(start.x, start.y);
        for (let i = 1; i < path.points.length; i++) {
          const pt = path.points[i];
          if (!pt) continue;
          const ptCanvas = resourceToCanvas(pt);
          ctx.lineTo(ptCanvas.x, ptCanvas.y);
        }
        
        if (path.closed) {
          ctx.closePath();
        }
        ctx.stroke();
      }
      
      ctx.setLineDash([]);
      ctx.globalAlpha = 1;
    }
    
    // Draw center lines (horizontal and vertical dashed gray cross)
    // Shows the design-time calculated center for mirror axis
    if (resource.center_x !== undefined && resource.center_y !== undefined) {
      const centerPoint = resourceToCanvas({ x: resource.center_x, y: resource.center_y });
      
      ctx.strokeStyle = '#c0c0c0'; // Light gray
      ctx.lineWidth = 1;
      ctx.setLineDash([4, 4]); // Dashed pattern
      ctx.globalAlpha = 0.6;
      
      // Vertical line
      ctx.beginPath();
      ctx.moveTo(centerPoint.x, 0);
      ctx.lineTo(centerPoint.x, height);
      ctx.stroke();
      
      // Horizontal line
      ctx.beginPath();
      ctx.moveTo(0, centerPoint.y);
      ctx.lineTo(width, centerPoint.y);
      ctx.stroke();
      
      ctx.setLineDash([]);
      ctx.globalAlpha = 1;
    }

    // Draw hovered vertex highlight (cyan ring — always on top)
    const hv = hoveredVertexRef.current;
    if (hv) {
      ctx.save();
      ctx.strokeStyle = '#00ffff';
      ctx.lineWidth = 2;
      ctx.globalAlpha = 0.9;
      ctx.beginPath();
      ctx.arc(hv.canvasX, hv.canvasY, 9, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }

    // Draw hovered segment insert indicator (green circle with + — always on top)
    const hs = hoveredSegmentRef.current;
    if (hs && currentTool === 'select') {
      ctx.save();
      ctx.strokeStyle = '#44ff88';
      ctx.fillStyle = '#44ff88';
      ctx.lineWidth = 2;
      ctx.globalAlpha = 0.9;
      ctx.beginPath();
      ctx.arc(hs.canvasX, hs.canvasY, 6, 0, Math.PI * 2);
      ctx.stroke();
      // Draw + symbol
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.moveTo(hs.canvasX - 4, hs.canvasY);
      ctx.lineTo(hs.canvasX + 4, hs.canvasY);
      ctx.moveTo(hs.canvasX, hs.canvasY - 4);
      ctx.lineTo(hs.canvasX, hs.canvasY + 4);
      ctx.stroke();
      ctx.restore();
    }
  }, [resource, currentLayerIndex, currentPathIndex, selectedPointIndex, selectedPoints, tempPoints, pan, zoom, width, height, resourceToCanvas, backgroundImage, backgroundOpacity, showBackground, isBoxSelecting, boxStart, boxEnd, showPreview, previewPaths, showEdgeSettings, isBackgroundSelected, backgroundOffset, isSubtractSelect, isMoveMode, selectedTreePathKey, selectedTreePathKeys, currentTool, showCollisionMesh, selectedEdge, walkAreaPreview]);

  useEffect(() => {
    draw();
  }, [draw]);

  // Handle image upload
  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const dataUrl = event.target?.result as string;
      const img = new Image();
      img.onload = () => {
        setBackgroundImage(img);
        setShowBackground(true);
        
        // Save the image data URL in the resource so it persists
        const newResource = { ...resource, backgroundImage: dataUrl };
        updateResource(resource, newResource);
      };
      img.src = dataUrl;
    };
    reader.readAsDataURL(file);
  };
  
  // DXF: approximate arc/circle as polygon points (shared helper)
  const dxfArcPoints = (cx: number, cy: number, cz: number, r: number, startDeg: number, endDeg: number, steps = 24): Point[] => {
    const pts: Point[] = [];
    let a0 = (startDeg * Math.PI) / 180;
    let a1 = (endDeg * Math.PI) / 180;
    if (a1 <= a0) a1 += 2 * Math.PI;
    for (let i = 0; i <= steps; i++) {
      const a = a0 + (a1 - a0) * (i / steps);
      pts.push({ x: cx + r * Math.cos(a), y: cy + r * Math.sin(a), z: cz });
    }
    return pts;
  };

  // Phase 1: parse DXF file and open the import dialog
  const handleDxfImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const text = ev.target?.result as string;
        const parser = new DxfParser();
        const dxf = parser.parseSync(text);
        if (!dxf || !dxf.entities) { alert('Could not parse DXF file.'); return; }

        const rawPaths: RawPath[] = [];
        for (const entity of dxf.entities as IEntity[]) {
          const ent = entity as any;
          switch (entity.type) {
            case 'LINE':
              rawPaths.push({ pts: (ent.vertices as any[]).map((v: any) => ({ x: v.x, y: v.y, z: v.z ?? 0 })), closed: false });
              break;
            case 'LWPOLYLINE':
              rawPaths.push({ pts: (ent.vertices as any[]).map((v: any) => ({ x: v.x, y: v.y, z: ent.elevation ?? 0 })), closed: !!ent.shape });
              break;
            case 'POLYLINE':
              rawPaths.push({ pts: (ent.vertices as any[]).map((v: any) => ({ x: v.x, y: v.y, z: v.z ?? 0 })), closed: !!ent.shape });
              break;
            case 'ARC':
              rawPaths.push({ pts: dxfArcPoints(ent.center.x, ent.center.y, ent.center.z ?? 0, ent.radius, ent.startAngle, ent.endAngle), closed: false });
              break;
            case 'CIRCLE':
              rawPaths.push({ pts: dxfArcPoints(ent.center.x, ent.center.y, ent.center.z ?? 0, ent.radius, 0, 360), closed: true });
              break;
            case 'SPLINE': {
              const pts: any[] = ent.fitPoints?.length ? ent.fitPoints : (ent.controlPoints ?? []);
              if (pts.length >= 2) rawPaths.push({ pts: pts.map((v: any) => ({ x: v.x, y: v.y, z: v.z ?? 0 })), closed: !!ent.closed });
              break;
            }
            default: break;
          }
        }

        if (rawPaths.length === 0) { alert('No supported geometry found in DXF.'); return; }

        // Compute 3D bounding box
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity, minZ = Infinity, maxZ = -Infinity;
        for (const rp of rawPaths) {
          for (const p of rp.pts) {
            if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
            if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
            const pz = p.z ?? 0;
            if (pz < minZ) minZ = pz; if (pz > maxZ) maxZ = pz;
          }
        }

        // Default scale: fit XY plane to ±127
        const defaultScale = 254 / Math.max(maxX - minX || 1, maxY - minY || 1);
        setDxfImport({ source: 'DXF', rawPaths, bbox: { minX, maxX, minY, maxY, minZ, maxZ }, referencePlane: 'xy', manualScale: parseFloat(defaultScale.toFixed(4)) });
      } catch (err) {
        alert('Error reading DXF: ' + (err as Error).message);
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Phase 2: apply scale and add paths to the current layer
  const confirmDxfImport = () => {
    if (!dxfImport) return;
    const { rawPaths, bbox, referencePlane, manualScale } = dxfImport;
    const { minX, maxX, minY, maxY, minZ, maxZ } = bbox;
    const rangeX = maxX - minX || 1, rangeY = maxY - minY || 1, rangeZ = maxZ - minZ || 1;

    let scale: number;
    if (referencePlane === 'xy') scale = 254 / Math.max(rangeX, rangeY);
    else if (referencePlane === 'xz') scale = 254 / Math.max(rangeX, rangeZ);
    else if (referencePlane === 'yz') scale = 254 / Math.max(rangeY, rangeZ);
    else scale = manualScale;

    const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2, cz = (minZ + maxZ) / 2;
    const clamp = (v: number) => Math.max(-127, Math.min(127, v));
    const prefix = dxfImport.source.toLowerCase();
    const newPaths: VecPath[] = rawPaths.map((rp, idx) => ({
      name: `${prefix}_${idx}`,
      intensity: 127,
      closed: rp.closed,
      points: rp.pts.map((p) => ({
        x: clamp(Math.round((p.x - cx) * scale)),
        y: clamp(Math.round((p.y - cy) * scale)),
        z: clamp(Math.round(((p.z ?? 0) - cz) * scale)),
      })),
    }));

    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    newResource.layers[currentLayerIndex].paths.push(...newPaths);
    updateResource(resource, newResource);
    setDxfImport(null);
  };

  // Handle OBJ import — extracts hard edges only (filters triangulation by dihedral angle)
  const handleObjImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const text = ev.target?.result as string;
        type Vec3 = [number, number, number];
        const verts: Vec3[] = [];
        const faces: number[][] = [];  // each face = list of vertex indices
        const linesExplicit: [number, number][] = [];

        for (const line of text.split('\n')) {
          const parts = line.trim().split(/\s+/);
          if (parts[0] === 'v') {
            verts.push([parseFloat(parts[1]) || 0, parseFloat(parts[2]) || 0, parseFloat(parts[3]) || 0]);
          } else if (parts[0] === 'f') {
            const indices = parts.slice(1).map((p) => parseInt(p.split('/')[0]) - 1);
            if (indices.length >= 3) faces.push(indices);
          } else if (parts[0] === 'l') {
            const indices = parts.slice(1).map((p) => parseInt(p) - 1);
            for (let i = 0; i < indices.length - 1; i++) linesExplicit.push([indices[i], indices[i + 1]]);
          }
        }

        if (verts.length === 0) { alert('No geometry found in OBJ file.'); return; }

        // Face normal helper
        const faceNormal = (face: number[]): Vec3 => {
          const [ax, ay, az] = verts[face[0]];
          const [bx, by, bz] = verts[face[1]];
          const [cx, cy, cz] = verts[face[2]];
          const ux = bx - ax, uy = by - ay, uz = bz - az;
          const vx = cx - ax, vy = cy - ay, vz = cz - az;
          const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
          const len = Math.sqrt(nx * nx + ny * ny + nz * nz) || 1;
          return [nx / len, ny / len, nz / len];
        };

        // Map each edge key → list of face normals sharing it
        const edgeFaces = new Map<string, Vec3[]>();
        for (const face of faces) {
          const n = faceNormal(face);
          for (let i = 0; i < face.length; i++) {
            const a = face[i], b = face[(i + 1) % face.length];
            if (a < 0 || b < 0 || a >= verts.length || b >= verts.length) continue;
            const key = `${Math.min(a, b)},${Math.max(a, b)}`;
            if (!edgeFaces.has(key)) edgeFaces.set(key, []);
            edgeFaces.get(key)!.push(n);
          }
        }

        // Keep edge if: border (only 1 face) OR dihedral angle > threshold
        // Build objEdges list (stores dot product per edge for re-filtering in the dialog)
        const objEdgeList: ObjEdge[] = [];
        for (const [key, normals] of edgeFaces) {
          const [a, b] = key.split(',').map(Number);
          if (normals.length === 1) {
            objEdgeList.push({ a, b, dot: -2, border: true, n1: normals[0] });
          } else {
            const [n1, n2] = normals;
            const dot = n1[0] * n2[0] + n1[1] * n2[1] + n1[2] * n2[2];
            objEdgeList.push({ a, b, dot, border: false, n1, n2 });
          }
        }
        // Add explicit 'l' lines
        for (const [a, b] of linesExplicit) {
          if (a >= 0 && b >= 0 && a < verts.length && b < verts.length)
            objEdgeList.push({ a, b, dot: -2, border: true });
        }

        const ANGLE_THRESHOLD_DEG = 25;
        const cosThreshold = Math.cos((ANGLE_THRESHOLD_DEG * Math.PI) / 180);
        const hardEdges: [number, number][] = objEdgeList
          .filter(e => e.border || e.dot < cosThreshold)
          .map(e => [e.a, e.b]);

        if (hardEdges.length === 0) { alert('No hard edges found. Try lowering the angle threshold or check the OBJ file.'); return; }

        const rawPaths = chainObjEdges(hardEdges, verts);

        // Compute 3D bounding box
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity, minZ = Infinity, maxZ = -Infinity;
        for (const [px, py, pz] of verts) {
          if (px < minX) minX = px; if (px > maxX) maxX = px;
          if (py < minY) minY = py; if (py > maxY) maxY = py;
          if (pz < minZ) minZ = pz; if (pz > maxZ) maxZ = pz;
        }

        const defaultScale = 254 / Math.max(maxX - minX || 1, maxY - minY || 1, maxZ - minZ || 1);
        setDxfImport({ source: 'OBJ', rawPaths, bbox: { minX, maxX, minY, maxY, minZ, maxZ }, referencePlane: 'xy', manualScale: parseFloat(defaultScale.toFixed(4)), objVerts: verts, objEdges: objEdgeList, angleThreshold: ANGLE_THRESHOLD_DEG, edgeMode: 'hard' });
      } catch (err) {
        alert('Error reading OBJ: ' + (err as Error).message);
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  // Sync background image with the active resource
  useEffect(() => {
    if (resource.backgroundImage) {
      const img = new Image();
      img.onload = () => {
        setBackgroundImage(img);
        setShowBackground(true);
      };
      img.src = resource.backgroundImage;
      setBackgroundOffset(resource.backgroundOffset ?? { x: 0, y: 0 });
    } else {
      setBackgroundImage(null);
      setShowBackground(false);
      setShowEdgeSettings(false);
      setBackgroundOffset({ x: 0, y: 0 });
    }
  }, [resource.backgroundImage]);

  // Auto-detect edges and create vectors
  const handleAutoDetect = async () => {
    if (!backgroundImage) return;
    
    setIsProcessing(true);
    
    // Use requestAnimationFrame to avoid blocking UI
    await new Promise(resolve => requestAnimationFrame(resolve));
    
    try {
      const paths = detectEdgesFromImage(
        backgroundImage,
        width,
        height,
        resource.canvas.width,
        resource.canvas.height,
        edgeOptions
      );
      
      if (paths.length > 0) {
        // Add detected paths to the main drawing layer (index 0)
        const newResource = { ...resource };
        // Ensure layer 0 exists
        if (!newResource.layers[0]) {
          newResource.layers[0] = { name: 'drawing', visible: true, paths: [] };
        }
        // Add traced paths to the main layer
        newResource.layers[0].paths.push(...paths);
        updateResource(resource, newResource);
      } else {
        alert('No edges detected. Try adjusting the threshold values.');
      }
    } catch (error) {
      console.error('Edge detection failed:', error);
      alert('Edge detection failed. Please try again with different settings.');
    } finally {
      setIsProcessing(false);
    }
  };

  // Track mouse drag for 3D rotation and panning
  const dragStartRef = useRef<{ x: number; y: number; panX: number; panY: number } | null>(null);
  
  // Mouse event handlers
  const handleMouseDown = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;

    // Right-click (button 2) → finalise pen path if drawing, otherwise ignore
    if (e.button === 2) {
      if (currentTool === 'bezier' && tempPoints.length >= 5) {
        e.preventDefault();
        finalizeBezierPath();
      } else if (currentTool === 'pen' && tempPoints.length >= 2) {
        e.preventDefault();
        finalizePenPath();
      }
      return;
    }

    // Middle mouse button (button 1) → temporary pan regardless of current tool
    if (e.button === 1) {
      e.preventDefault();
      const canvasX = e.clientX - rect.left;
      const canvasY = e.clientY - rect.top;
      dragStartRef.current = { x: canvasX, y: canvasY, panX: pan.x, panY: pan.y };
      setIsDrawing(true);
      return;
    }

    const canvasX = e.clientX - rect.left;
    const canvasY = e.clientY - rect.top;

    // With background tool, allow moving the background image
    if (currentTool === 'background') {
      // Check if clicking on background
      if (backgroundImage && showBackground) {
        dragStartRef.current = { x: canvasX, y: canvasY, panX: backgroundOffset.x, panY: backgroundOffset.y };
        setIsBackgroundSelected(true);
        setIsDrawing(true);
      }
      return;
    }
    
    // With pan tool, allow rotation in 3D or panning in ortho views
    if (currentTool === 'pan') {
      dragStartRef.current = { x: canvasX, y: canvasY, panX: pan.x, panY: pan.y };
      setIsDrawing(true);
      return;
    }

    // Walkable-area paint: click-drag horizontally to define a [x_min,x_max] at y.
    if (currentTool === 'walkarea') {
      const p = canvasToResource(canvasX, canvasY);
      walkAreaDrawStartRef.current = { x: Math.round(p.x), y: Math.round(p.y) };
      setWalkAreaPreview({ y: Math.round(p.y), x_min: Math.round(p.x), x_max: Math.round(p.x) });
      setIsDrawing(true);
      return;
    }

    const point = canvasToResource(canvasX, canvasY);

    if (currentTool === 'pen') {
      // Snap to nearest existing vertex if within snap radius (preserves full 3D coords)
      const snapped = hoveredVertexRef.current;
      const penPoint = snapped ? { x: snapped.point.x, y: snapped.point.y, z: snapped.point.z ?? 0 } : point;
      setTempPoints([...tempPoints, penPoint]);
      setIsDrawing(true);
    } else if (currentTool === 'bezier') {
      bezierMouseDownRef.current = { canvasX, canvasY, resPoint: point };
      setIsDrawing(true);
    } else if (currentTool === 'circle' || currentTool === 'arc' || currentTool === 'polygon') {
      // Start drawing circle/arc/polygon - set center
      setCircleCenter(point);
      setCircleRadius(0);
      setIsDrawing(true);
    } else if (currentTool === 'select') {
      // Check if clicking on a point or near a path line
      let closestDist = Infinity;
      let closestPath = -1;
      let closestPoint = -1;
      let closestPathLineDistance = Infinity;

      const layer = resource.layers[currentLayerIndex];
      if (!layer || !Array.isArray(layer.paths)) return;
      
      // First check for point clicks
      // In 3D mode use a slightly larger threshold and prefer front vertices (smaller z = closer)
      const hitThreshold = viewMode === '3d' ? 14 : 10;
      let closestZ = Infinity;
      for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
        const path = layer.paths[pathIdx];
        if (!path || !Array.isArray(path.points)) continue;
        for (let pointIdx = 0; pointIdx < path.points.length; pointIdx++) {
          const ptRaw = path.points[pointIdx];
          if (!ptRaw) continue;
          const pt = resourceToCanvasWithDepth(ptRaw);
          const dist = Math.sqrt((pt.x - canvasX) ** 2 + (pt.y - canvasY) ** 2);
          if (dist < hitThreshold) {
            // Prefer the vertex that is strictly closer on screen; break ties by depth
            const betterDist = dist < closestDist - 0.5;
            const sameDist = Math.abs(dist - closestDist) <= 0.5;
            if (betterDist || (sameDist && pt.z < closestZ)) {
              closestDist = dist;
              closestZ = pt.z;
              closestPath = pathIdx;
              closestPoint = pointIdx;
            }
          }
        }
      }

      // If no point clicked, check if clicking near a path line
      if (closestPath < 0) {
        for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
          const path = layer.paths[pathIdx];
          if (!path || !Array.isArray(path.points) || path.points.length < 2) continue;
          
          // Check distance to path lines
          for (let i = 0; i < path.points.length - 1; i++) {
            const p1Raw = path.points[i];
            const p2Raw = path.points[i + 1];
            if (!p1Raw || !p2Raw) continue;
            
            const p1 = resourceToCanvas(p1Raw);
            const p2 = resourceToCanvas(p2Raw);
            
            // Distance from point to line segment
            const dist = pointToLineDistance(canvasX, canvasY, p1.x, p1.y, p2.x, p2.y);
            if (dist < closestPathLineDistance && dist < 8) {
              closestPathLineDistance = dist;
              closestPath = pathIdx;
              closestPoint = -1; // No specific point, just the path
            }
          }
        }
      }

      if (closestPath >= 0) {
        // Clicked on a point or path - select it
        setCurrentPathIndex(closestPath);
        if (closestPoint >= 0) {
          setSelectedPointIndex(closestPoint);
          const key = `${closestPath}-${closestPoint}`;
          let newSelection: Set<string>;
          if (e.shiftKey) {
            // Add to selection
            newSelection = new Set([...selectedPoints, key]);
          } else {
            newSelection = new Set([key]);
          }
          setSelectedPoints(newSelection);
          // Snapshot all selected point positions for multi-drag
          const startRes = canvasToResource(canvasX, canvasY);
          dragStartResCoordRef.current = { x: startRes.x, y: startRes.y };
          const startPositions = new Map<string, { x: number; y: number }>();
          for (const k of newSelection) {
            const [pIdx, ptIdx] = k.split('-').map(Number);
            const pt = resource.layers[currentLayerIndex]?.paths[pIdx]?.points[ptIdx];
            if (pt) startPositions.set(k, { x: pt.x, y: pt.y });
          }
          dragStartPositionsRef.current = startPositions;
          setSelectedEdge(null); // point selected, not an edge
        } else {
          // Clicked on path line but not a point - select the path and remember which edge
          setSelectedPointIndex(-1);
          if (!e.shiftKey) {
            setSelectedPoints(new Set());
          }
          const seg = hoveredSegmentRef.current;
          if (seg && seg.pathIdx === closestPath) {
            setSelectedEdge({ pathIdx: closestPath, edgeIdx: seg.segIdx });
          } else {
            setSelectedEdge(null);
          }
        }
        setIsDrawing(true); // Enable dragging
      } else {
        // No point clicked
        if (isMoveMode && selectedPoints.size > 0) {
          // M-mode: drag from empty canvas space to move all selected points
          const startRes = canvasToResource(canvasX, canvasY);
          dragStartResCoordRef.current = { x: startRes.x, y: startRes.y };
          const startPositions = new Map<string, { x: number; y: number }>();
          for (const k of selectedPoints) {
            const [pIdx, ptIdx] = k.split('-').map(Number);
            const pt = resource.layers[currentLayerIndex]?.paths[pIdx]?.points[ptIdx];
            if (pt) startPositions.set(k, { x: pt.x, y: pt.y });
          }
          dragStartPositionsRef.current = startPositions;
          setIsDrawing(true);
        } else {
          // Start box selection
          setIsBoxSelecting(true);
          setBoxStart({ x: canvasX, y: canvasY });
          setBoxEnd({ x: canvasX, y: canvasY });
          setIsSubtractSelect(e.shiftKey);
          if (!e.shiftKey) {
            setSelectedPoints(new Set());
            setSelectedPointIndex(-1);
            setCurrentPathIndex(-1);
          }
        }
      }
    }
  };

  const handleMouseMove = (e: React.MouseEvent<HTMLCanvasElement>) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;

    const canvasX = e.clientX - rect.left;
    const canvasY = e.clientY - rect.top;
    
    // Update Vectrex coordinates display
    const vectrexPoint = canvasToResource(canvasX, canvasY);
    setMouseVectrexCoords({ x: vectrexPoint.x, y: vectrexPoint.y });

    // Track mouse position for rubber-band preview; redraw if pen is mid-path
    mousePenPosRef.current = { x: canvasX, y: canvasY };

    // Live walkable-area preview while click-dragging.
    if (currentTool === 'walkarea' && isDrawing && walkAreaDrawStartRef.current) {
      const p = canvasToResource(canvasX, canvasY);
      const start = walkAreaDrawStartRef.current;
      const x_min = Math.round(Math.min(start.x, p.x));
      const x_max = Math.round(Math.max(start.x, p.x));
      setWalkAreaPreview({ y: start.y, x_min, x_max });
      draw();
      return;
    }

    // Update hovered vertex (highlight nearest vertex within snap radius)
    const prev = hoveredVertexRef.current;
    const nearest = findNearestVertex(canvasX, canvasY);
    hoveredVertexRef.current = nearest;

    // Update hovered segment for insert-point indicator (select mode only, when no vertex is hovered)
    const prevSeg = hoveredSegmentRef.current;
    if (currentTool === 'select' && !nearest) {
      const layer = resource.layers[currentLayerIndex];
      let bestSeg: typeof hoveredSegmentRef.current = null;
      let bestDist = 10; // px threshold for segment hover
      if (layer && Array.isArray(layer.paths)) {
        for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
          const path = layer.paths[pathIdx];
          if (!path || !Array.isArray(path.points) || path.points.length < 2) continue;
          for (let i = 0; i < path.points.length - 1; i++) {
            const p1 = resourceToCanvas(path.points[i]!);
            const p2 = resourceToCanvas(path.points[i + 1]!);
            const proj = projectOnSegment(canvasX, canvasY, p1.x, p1.y, p2.x, p2.y);
            if (proj && proj.dist < bestDist) {
              bestDist = proj.dist;
              const r1 = path.points[i]!;
              const r2 = path.points[i + 1]!;
              bestSeg = {
                pathIdx,
                segIdx: i,
                canvasX: proj.canvasX,
                canvasY: proj.canvasY,
                resPoint: {
                  x: Math.round(r1.x + proj.t * (r2.x - r1.x)),
                  y: Math.round(r1.y + proj.t * (r2.y - r1.y)),
                  z: r1.z !== undefined && r2.z !== undefined ? Math.round(r1.z + proj.t * (r2.z - r1.z)) : 0,
                },
              };
            }
          }
        }
      }
      hoveredSegmentRef.current = bestSeg;
    } else {
      hoveredSegmentRef.current = null;
    }

    if (nearest !== null || prev !== null || hoveredSegmentRef.current !== prevSeg) {
      draw(); // redraw to show/hide highlights
    } else if ((currentTool === 'pen' || currentTool === 'bezier') && tempPoints.length > 0) {
      draw();
    } else if (currentTool === 'bezier' && bezierMouseDownRef.current) {
      draw();
    }

    // Middle mouse button drag → pan (e.buttons bit 4 = middle button held)
    if (e.buttons === 4 && dragStartRef.current) {
      const deltaX = canvasX - dragStartRef.current.x;
      const deltaY = canvasY - dragStartRef.current.y;
      setPan({ x: dragStartRef.current.panX + deltaX, y: dragStartRef.current.panY + deltaY });
      return;
    }

    // Handle background movement with background tool
    if (currentTool === 'background' && isDrawing && dragStartRef.current && isBackgroundSelected) {
      const deltaX = canvasX - dragStartRef.current.x;
      const deltaY = canvasY - dragStartRef.current.y;
      
      setBackgroundOffset({
        x: dragStartRef.current.panX + deltaX,
        y: dragStartRef.current.panY + deltaY,
      });
      return;
    }
    
    // Handle rotation/panning with pan tool
    if (currentTool === 'pan' && isDrawing && dragStartRef.current) {
      const deltaX = canvasX - dragStartRef.current.x;
      const deltaY = canvasY - dragStartRef.current.y;
      
      if (viewMode === '3d') {
        // 3D rotation
        setRotation3D({
          pitch: Math.max(-89, Math.min(89, rotation3D.pitch - deltaY * 0.5)),
          yaw: (rotation3D.yaw + deltaX * 0.5) % 360,
        });
        dragStartRef.current = { ...dragStartRef.current, x: canvasX, y: canvasY };
      } else {
        // Ortho view panning
        setPan({
          x: dragStartRef.current.panX + deltaX,
          y: dragStartRef.current.panY + deltaY,
        });
      }
      return;
    }
    
    if (isBoxSelecting && currentTool === 'select') {
      // Update box selection
      setBoxEnd({ x: canvasX, y: canvasY });
      return;
    }
    
    // Handle circle/arc/polygon radius dragging
    if ((currentTool === 'circle' || currentTool === 'arc' || currentTool === 'polygon') && isDrawing && circleCenter) {
      const point = canvasToResource(canvasX, canvasY);
      const dx = point.x - circleCenter.x;
      const dy = point.y - circleCenter.y;
      const radius = Math.round(Math.sqrt(dx * dx + dy * dy));
      circlePreviewRef.current = { center: circleCenter, tool: currentTool, radius };
      setCircleRadius(radius);
      draw();
      return;
    }

    if (!isDrawing || currentTool !== 'select') return;

    const point = canvasToResource(canvasX, canvasY);

    // Multi-point drag: apply delta from mouseDown position to ALL selected points
    if (dragStartPositionsRef.current && dragStartResCoordRef.current) {
      const dx = point.x - dragStartResCoordRef.current.x;
      const dy = point.y - dragStartResCoordRef.current.y;
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      for (const [key, startPos] of dragStartPositionsRef.current) {
        const [pIdx, ptIdx] = key.split('-').map(Number);
        const path = newResource.layers[currentLayerIndex]?.paths[pIdx];
        if (path?.points[ptIdx]) {
          path.points[ptIdx].x = Math.round(Math.max(-127, Math.min(127, startPos.x + dx)));
          path.points[ptIdx].y = Math.round(Math.max(-127, Math.min(127, startPos.y + dy)));
        }
      }
      updateResource(resource, newResource);
      return;
    }

    // Single-point drag fallback (no longer reached when a point is clicked, kept for safety)
    if (selectedPointIndex >= 0 && currentPathIndex >= 0) {
      const newResource = { ...resource };
      newResource.layers[currentLayerIndex].paths[currentPathIndex].points[selectedPointIndex] = point;
      updateResource(resource, newResource);
    }
  };

  const handleMouseUp = () => {
    // Persist background offset if the background was dragged
    if (currentTool === 'background' && isDrawing && isBackgroundSelected && dragStartRef.current) {
      const nr = { ...resource, backgroundOffset: backgroundOffset };
      updateResource(resource, nr);
    }

    // Finalise walkable-area paint: commit the preview as a new area on the resource.
    if (currentTool === 'walkarea' && isDrawing && walkAreaPreview && walkAreaDrawStartRef.current) {
      const a = walkAreaPreview;
      if (a.x_max - a.x_min >= 2) {
        const next = [...(resource.walkableAreas ?? []), { y: a.y, x_min: a.x_min, x_max: a.x_max }];
        updateResource(resource, { ...resource, walkableAreas: next });
      }
      walkAreaDrawStartRef.current = null;
      setWalkAreaPreview(null);
      setIsDrawing(false);
    }

    // Clear drag state for 3D rotation
    dragStartRef.current = null;
    setIsBackgroundSelected(false);
    
    // Finalize bezier anchor placement
    if (currentTool === 'bezier' && isDrawing && bezierMouseDownRef.current) {
      const md = bezierMouseDownRef.current;
      bezierMouseDownRef.current = null;

      const rect2 = canvasRef.current?.getBoundingClientRect();
      // Use the last known mouse position; if unavailable, use the mousedown point
      const curMouseCanvas = mousePenPosRef.current ?? { x: md.canvasX, y: md.canvasY };
      const curMouseRes = canvasToResource(curMouseCanvas.x, curMouseCanvas.y);

      const anchor = { ...md.resPoint, t: 'a' as const };
      const ddx = curMouseRes.x - md.resPoint.x;
      const ddy = curMouseRes.y - md.resPoint.y;
      const isDrag = Math.abs(ddx) > 2 || Math.abs(ddy) > 2;

      const cpOut: Point = isDrag
        ? { x: Math.round(md.resPoint.x + ddx), y: Math.round(md.resPoint.y + ddy), t: 'c' }
        : { ...md.resPoint, t: 'c' };
      const cpIn: Point = isDrag
        ? { x: Math.round(md.resPoint.x - ddx), y: Math.round(md.resPoint.y - ddy), t: 'c' }
        : { ...md.resPoint, t: 'c' };

      if (tempPoints.length === 0) {
        // First anchor: [A0, C0_out]
        setTempPoints([anchor, cpOut]);
      } else {
        // Subsequent: append [C_in, A, C_out]
        setTempPoints(prev => [...prev, cpIn, anchor, cpOut]);
      }
      setIsDrawing(false);
      void rect2; // suppress unused warning
      return;
    }

    // Finalize circle/arc/polygon
    if ((currentTool === 'circle' || currentTool === 'arc' || currentTool === 'polygon') && isDrawing && circleCenter && circleRadius > 0) {
      const points = currentTool === 'circle'
        ? generateCirclePoints(circleCenter, circleRadius, circleSegments, true)
        : currentTool === 'polygon'
        ? generatePolygonPoints(circleCenter, circleRadius, polygonSides)
        : generateArcPoints(circleCenter, circleRadius, arcStartAngle, arcEndAngle, circleSegments);
      
      const newPath: VecPath = {
        name: currentTool === 'circle' ? `circle_${Date.now()}` : currentTool === 'polygon' ? `polygon_${Date.now()}` : `arc_${Date.now()}`,
        intensity: 127,
        closed: currentTool === 'circle' || currentTool === 'polygon',
        points,
      };
      
      const newResource = { ...resource };
      const layer = newResource.layers[currentLayerIndex];
      layer.paths.push(newPath);
      updateResource(resource, newResource);
      
      // Reset circle/arc state
      setCircleCenter(null);
      setCircleRadius(0);
      circlePreviewRef.current = null;
    }
    
    // Complete box selection
    if (isBoxSelecting && boxStart && boxEnd) {
      const minX = Math.min(boxStart.x, boxEnd.x);
      const maxX = Math.max(boxStart.x, boxEnd.x);
      const minY = Math.min(boxStart.y, boxEnd.y);
      const maxY = Math.max(boxStart.y, boxEnd.y);

      // Find all points within the box
      const layer = resource.layers[currentLayerIndex];
      const newlySelected: string[] = [];

      for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
        const path = layer.paths[pathIdx];
        for (let pointIdx = 0; pointIdx < path.points.length; pointIdx++) {
          const canvasPt = resourceToCanvas(path.points[pointIdx]);
          if (canvasPt.x >= minX && canvasPt.x <= maxX &&
              canvasPt.y >= minY && canvasPt.y <= maxY) {
            newlySelected.push(`${pathIdx}-${pointIdx}`);
          }
        }
      }

      if (isSubtractSelect) {
        // Remove newly selected points from the existing selection
        const next = new Set(selectedPoints);
        for (const key of newlySelected) next.delete(key);
        setSelectedPoints(next);
      } else {
        // Add newly selected points to the existing selection
        setSelectedPoints(new Set([...selectedPoints, ...newlySelected]));
      }

      setIsSubtractSelect(false);
      setIsBoxSelecting(false);
      setBoxStart(null);
      setBoxEnd(null);
    }

    // Clear multi-drag state
    dragStartPositionsRef.current = null;
    dragStartResCoordRef.current = null;

    setIsDrawing(false);
  };
  
  // Handle mouse wheel for zoom (zoom to cursor position)
  // Registered as a native listener (passive: false) so preventDefault() works in Chrome/Electron.
  const handleWheel = useCallback((e: WheelEvent) => {
    e.preventDefault();
    
    const canvas = canvasRef.current;
    if (!canvas) return;
    
    // Get mouse position relative to canvas
    const rect = canvas.getBoundingClientRect();
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    
    // Calculate world position before zoom
    const centerX = width / 2;
    const centerY = height / 2;
    const scale = Math.min(width, height) / resource.canvas.width;
    
    const worldX = (mouseX - centerX - pan.x) / (scale * zoom);
    const worldY = (mouseY - centerY - pan.y) / (scale * zoom);
    
    // Calculate new zoom
    const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
    const newZoom = Math.max(0.5, Math.min(16, zoom * zoomFactor));
    
    // Calculate new pan to keep world position under cursor
    const newPanX = mouseX - centerX - worldX * scale * newZoom;
    const newPanY = mouseY - centerY - worldY * scale * newZoom;
    
    setZoom(newZoom);
    setPan({ x: newPanX, y: newPanY });
  }, [zoom, pan, width, height, resource.canvas.width]);

  // Register wheel as non-passive so preventDefault() works
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    canvas.addEventListener('wheel', handleWheel, { passive: false });
    return () => canvas.removeEventListener('wheel', handleWheel);
  }, [handleWheel]);
  
  // Delete selected points
  const handleDeleteSelected = useCallback(() => {
    if (selectedPoints.size === 0) return;
    
    // DEEP COPY to avoid modifying the original resource
    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    const layer = newResource.layers[currentLayerIndex];
    
    // Count total points before deletion
    const pointsBefore = layer.paths.reduce((sum, p) => sum + p.points.length, 0);
    console.log('[VectorEditor] DELETE: Points before:', pointsBefore, 'Deleting:', selectedPoints.size);
    
    // Group selections by path and sort in reverse order to delete from end
    const pointsByPath: Map<number, number[]> = new Map();
    selectedPoints.forEach(key => {
      const [pathIdx, pointIdx] = key.split('-').map(Number);
      if (!pointsByPath.has(pathIdx)) {
        pointsByPath.set(pathIdx, []);
      }
      pointsByPath.get(pathIdx)!.push(pointIdx);
    });
    
    // Delete points in reverse order to maintain indices
    pointsByPath.forEach((pointIndices, pathIdx) => {
      pointIndices.sort((a, b) => b - a); // Sort descending
      pointIndices.forEach(pointIdx => {
        layer.paths[pathIdx].points.splice(pointIdx, 1);
      });
    });
    
    // Remove empty paths
    layer.paths = layer.paths.filter(p => p.points.length > 0);
    
    // Count total points after deletion
    const pointsAfter = layer.paths.reduce((sum, p) => sum + p.points.length, 0);
    console.log('[VectorEditor] DELETE: Points after:', pointsAfter);
    
    updateResource(resource, newResource);
    setSelectedPoints(new Set());
    setSelectedPointIndex(-1);
    setCurrentPathIndex(-1);
  }, [resource, currentLayerIndex, selectedPoints, updateResource]);

  // Delete all tree-selected paths
  const handleDeleteTreePaths = useCallback((overrideKeys?: Set<string>) => {
    const keysToDelete = overrideKeys ?? (selectedTreePathKeys.size > 0 ? selectedTreePathKeys
      : (selectedTreePathKey ? new Set([selectedTreePathKey]) : new Set<string>()));
    if (keysToDelete.size === 0) return;
    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    const byLayer = new Map<number, number[]>();
    keysToDelete.forEach(key => {
      const [li, pi] = key.split('-').map(Number);
      if (!byLayer.has(li)) byLayer.set(li, []);
      byLayer.get(li)!.push(pi);
    });
    byLayer.forEach((pathIndices, li) => {
      pathIndices.sort((a, b) => b - a);
      pathIndices.forEach(pi => newResource.layers[li].paths.splice(pi, 1));
    });
    updateResource(resource, newResource);
    setSelectedTreePathKey(null);
    setSelectedTreePathKeys(new Set());
    setCurrentPathIndex(-1);
    setSelectedPointIndex(-1);
  }, [resource, selectedTreePathKey, selectedTreePathKeys, updateResource]);

  // Set intensity on all selected paths (from tree selection OR from canvas point selection)
  const handleSetIntensitySelected = useCallback((intensity: number) => {
    // Build set of "layerIdx-pathIdx" keys from tree selection
    const keysFromTree = selectedTreePathKeys.size > 0 ? selectedTreePathKeys
      : (selectedTreePathKey ? new Set([selectedTreePathKey]) : new Set<string>());
    // Also derive paths from selected canvas points (format "pathIdx-pointIdx", layer = currentLayerIndex)
    const keysFromPoints = new Set<string>();
    if (selectedPoints.size > 0) {
      selectedPoints.forEach(key => {
        const pathIdx = key.split('-')[0];
        keysFromPoints.add(`${currentLayerIndex}-${pathIdx}`);
      });
    } else if (selectedPointIndex >= 0 && currentPathIndex >= 0) {
      keysFromPoints.add(`${currentLayerIndex}-${currentPathIndex}`);
    }
    const allKeys = new Set([...keysFromTree, ...keysFromPoints]);
    if (allKeys.size === 0) return;
    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    allKeys.forEach(key => {
      const [li, pi] = key.split('-').map(Number);
      if (newResource.layers[li]?.paths[pi]) {
        newResource.layers[li].paths[pi].intensity = intensity;
      }
    });
    updateResource(resource, newResource);
  }, [resource, selectedTreePathKey, selectedTreePathKeys, selectedPoints, selectedPointIndex, currentPathIndex, currentLayerIndex, updateResource]);

  // Clean orphan paths: remove paths with <=1 point and fix incomplete bezier structures
  const handleCleanOrphans = useCallback(() => {
    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    let changed = false;
    for (const layer of newResource.layers) {
      const before = layer.paths.length;
      layer.paths = layer.paths.filter(p => {
        if (p.points.length <= 1) { changed = true; return false; }
        if ((p as VecPath & { type?: string }).type === 'bezier' && p.points.length < 4) { changed = true; return false; }
        return true;
      });
      if (layer.paths.length !== before) changed = true;
      // Trim trailing orphan bezier control points so (pts-1) % 3 === 0
      for (const p of layer.paths) {
        if ((p as VecPath & { type?: string }).type === 'bezier') {
          const rem = (p.points.length - 1) % 3;
          if (rem !== 0) {
            p.points.splice(p.points.length - rem, rem);
            changed = true;
          }
        }
      }
    }
    if (changed) {
      updateResource(resource, newResource);
      setSelectedTreePathKey(null);
      setSelectedTreePathKeys(new Set());
      setCurrentPathIndex(-1);
      setSelectedPointIndex(-1);
    }
  }, [resource, updateResource]);

  // Finalise the in-progress pen path (Enter, right-click, or double-click)
  const finalizePenPath = () => {
    mousePenPosRef.current = null;
    if (currentTool === 'pen' && tempPoints.length >= 2) {
      const newPath: VecPath = {
        name: `path_${Date.now()}`,
        intensity: 127,
        closed: false,
        points: [...tempPoints],
      };
      const newResource = { ...resource };
      newResource.layers[currentLayerIndex].paths.push(newPath);
      updateResource(resource, newResource);
      setTempPoints([]);
      setCurrentPathIndex(newResource.layers[currentLayerIndex].paths.length - 1);
    }
  };

  const finalizeBezierPath = () => {
    mousePenPosRef.current = null;
    bezierMouseDownRef.current = null;
    if (currentTool === 'bezier' && tempPoints.length >= 5) {
      // Remove trailing C_out (not needed after last anchor)
      const raw = tempPoints.slice(0, -1);
      // Tag types by position: i%3===0 → anchor, else → control
      const tagged = raw.map((p, i) => ({ ...p, t: (i % 3 === 0 ? 'a' : 'c') as 'a' | 'c' }));
      const newPath: VecPath = {
        name: `bezier_${Date.now()}`,
        intensity: 127,
        closed: false,
        type: 'bezier',
        points: tagged,
      };
      const newResource = { ...resource };
      newResource.layers[currentLayerIndex].paths.push(newPath);
      updateResource(resource, newResource);
      setTempPoints([]);
      setCurrentPathIndex(newResource.layers[currentLayerIndex].paths.length - 1);
    } else {
      setTempPoints([]);
    }
  };

  const handleDoubleClick = () => {
    mousePenPosRef.current = null;

    // In select mode: insert a point on the hovered segment
    if (currentTool === 'select') {
      const seg = hoveredSegmentRef.current;
      if (!seg) return;
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      const path = newResource.layers[currentLayerIndex]?.paths[seg.pathIdx];
      if (!path) return;
      path.points.splice(seg.segIdx + 1, 0, seg.resPoint);
      updateResource(resource, newResource);
      setCurrentPathIndex(seg.pathIdx);
      setSelectedPointIndex(seg.segIdx + 1);
      setSelectedPoints(new Set([`${seg.pathIdx}-${seg.segIdx + 1}`]));
      hoveredSegmentRef.current = null;
      return;
    }

    if (currentTool === 'bezier') {
      finalizeBezierPath();
      return;
    }

    if (currentTool === 'pen' && tempPoints.length >= 3) {
      // The second click of the double-click already added a duplicate last point;
      // trim it before materialising the path
      const points = tempPoints.slice(0, -1);
      const newPath: VecPath = {
        name: `path_${Date.now()}`,
        intensity: 127,
        closed: false,
        points,
      };
      const newResource = { ...resource };
      newResource.layers[currentLayerIndex].paths.push(newPath);
      updateResource(resource, newResource);
      setTempPoints([]);
      setCurrentPathIndex(newResource.layers[currentLayerIndex].paths.length - 1);
    } else {
      finalizePenPath();
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    // Undo/Redo shortcuts (Ctrl+Z, Ctrl+Shift+Z or Cmd+Z, Cmd+Shift+Z on Mac)
    if ((e.ctrlKey || e.metaKey) && e.key === 'z') {
      e.preventDefault();
      if (e.shiftKey) {
        handleRedo();
      } else {
        handleUndo();
      }
      e.stopPropagation();
      return;
    }

    // Copy selected paths to global clipboard
    if ((e.ctrlKey || e.metaKey) && e.key === 'c') {
      e.preventDefault();
      const pathIndices = new Set<number>();
      for (const key of selectedPoints) {
        pathIndices.add(parseInt(key.split('-')[0]));
      }
      if (pathIndices.size > 0) {
        const layer = resource.layers[currentLayerIndex];
        const copied = [...pathIndices].sort((a, b) => a - b).map(i =>
          JSON.parse(JSON.stringify(layer.paths[i]))
        );
        useEditorStore.getState().setVecClipboard(copied);
      }
      e.stopPropagation();
      return;
    }

    // Paste paths from global clipboard
    if ((e.ctrlKey || e.metaKey) && e.key === 'v') {
      e.preventDefault();
      const clipboard = useEditorStore.getState().vecClipboard;
      if (clipboard && clipboard.length > 0) {
        const PASTE_OFFSET = 10;
        const pasted = clipboard.map((path: any) => ({
          ...JSON.parse(JSON.stringify(path)),
          name: `${path.name}_copy`,
          points: path.points.map((pt: any) => ({
            ...pt,
            x: Math.max(-127, Math.min(127, pt.x + PASTE_OFFSET)),
            y: Math.max(-127, Math.min(127, pt.y + PASTE_OFFSET)),
          }))
        }));
        const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
        const insertIdx = newResource.layers[currentLayerIndex].paths.length;
        newResource.layers[currentLayerIndex].paths.push(...pasted);
        updateResource(resource, newResource);
        // Auto-select all points of pasted paths
        const newSelected = new Set<string>();
        for (let i = 0; i < pasted.length; i++) {
          for (let j = 0; j < pasted[i].points.length; j++) {
            newSelected.add(`${insertIdx + i}-${j}`);
          }
        }
        setSelectedPoints(newSelected);
      }
      e.stopPropagation();
      return;
    }
    
    // View switching shortcuts
    if (e.key === '1') {
      setViewMode('xy');
      return;
    } else if (e.key === '2') {
      setViewMode('xz');
      return;
    } else if (e.key === '3') {
      setViewMode('yz');
      return;
    } else if (e.key === '4') {
      setViewMode('3d');
      return;
    }
    
    if (e.key === 'Enter') {
      e.preventDefault();
      if (currentTool === 'bezier') finalizeBezierPath();
      else finalizePenPath();
      return;
    }

    if (e.key === 'Escape') {
      mousePenPosRef.current = null;
      setTempPoints([]);
      setSelectedPointIndex(-1);
      setSelectedPoints(new Set());
      setIsBoxSelecting(false);
      setBoxStart(null);
      setBoxEnd(null);
      setIsMoveMode(false);
    } else if (e.key === 'm' || e.key === 'M') {
      if (!e.ctrlKey && !e.metaKey && !e.altKey) {
        setIsMoveMode(prev => !prev);
      }
    } else if (e.key === 'Delete' || e.key === 'Backspace') {
      e.preventDefault();
      e.stopPropagation(); // Prevent FileTreePanel from handling this event
      if (selectedPoints.size > 0) {
        handleDeleteSelected();
      } else if (selectedTreePathKeys.size > 0 || (selectedTreePathKey && selectedPointIndex < 0)) {
        handleDeleteTreePaths();
      } else if (selectedPointIndex >= 0 && currentPathIndex >= 0) {
        const newResource = { ...resource };
        const pointsBefore = newResource.layers[currentLayerIndex].paths[currentPathIndex].points.length;
        console.log('[VectorEditor] DELETE POINT: Path', currentPathIndex, 'Point', selectedPointIndex, 'Before:', pointsBefore);
        newResource.layers[currentLayerIndex].paths[currentPathIndex].points.splice(selectedPointIndex, 1);
        const pointsAfter = newResource.layers[currentLayerIndex].paths[currentPathIndex].points.length;
        console.log('[VectorEditor] DELETE POINT: After:', pointsAfter);
        updateResource(resource, newResource);
        setSelectedPointIndex(-1);
      }
    }
  };

  // Center vector - move all points so that center aligns to (0,0)
  const centerVector = useCallback(() => {
    const newResource = { ...resource };
    const center_x = newResource.center_x || 0;
    const center_y = newResource.center_y || 0;
    
    if (center_x === 0 && center_y === 0) {
      return; // Already centered
    }

    // Move all points by -center offset
    newResource.layers.forEach(layer => {
      layer.paths.forEach(path => {
        path.points.forEach(point => {
          point.x -= center_x;
          point.y -= center_y;
        });
      });
    });

    updateResource(resource, newResource);
  }, [resource, updateResource]);

  // Mirror vector X - flip horizontally (negate X coordinates only)
  const mirrorVectorX = useCallback(() => {
    const newResource = { ...resource };

    // Negate only X coordinates
    newResource.layers.forEach(layer => {
      layer.paths.forEach(path => {
        path.points.forEach(point => {
          point.x = -point.x;
        });
      });
    });

    updateResource(resource, newResource);
  }, [resource, updateResource]);

  // Simplify — apply Ramer-Douglas-Peucker to all paths in ALL layers
  // Removes near-collinear intermediate points (invisible at Vectrex scale).
  // Supports undo via the standard updateResource history mechanism.
  const handleSimplify = useCallback((epsilon: number = 2.0) => {
    const newResource: VecResource = {
      ...resource,
      layers: resource.layers.map(layer => ({
        ...layer,
        paths: layer.paths.map(path => {
          const simplified = simplifyPath(path.points, epsilon);
          // Only update if we actually removed points
          if (simplified.length === path.points.length) return path;
          return { ...path, points: simplified };
        }),
      })),
    };

    // Count removed points for feedback
    const origPts = resource.layers.flatMap(l => l.paths).reduce((s, p) => s + p.points.length, 0);
    const newPts  = newResource.layers.flatMap(l => l.paths).reduce((s, p) => s + p.points.length, 0);
    const removed = origPts - newPts;
    if (removed === 0) {
      console.log('[VectorEditor] Simplify: nothing to remove at epsilon=' + epsilon);
      return;
    }
    console.log(`[VectorEditor] Simplify ε=${epsilon}: removed ${removed} pts (${origPts}→${newPts}), ~${Math.round(removed/origPts*100)}%`);
    updateResource(resource, newResource);
  }, [resource, updateResource]);

  // Chain edges — merge 2-point open paths that share endpoints into polylines
  const chainEdges = useCallback(() => {
    const layer = resource.layers[currentLayerIndex];
    if (!layer) return;

    // Separate paths into 2-point edges (candidates) and everything else (keep as-is)
    const edgePaths: VecPath[] = [];
    const otherPaths: VecPath[] = [];
    for (const path of layer.paths) {
      if (!path.closed && path.points.length === 2) {
        edgePaths.push(path);
      } else {
        otherPaths.push(path);
      }
    }

    if (edgePaths.length < 2) return; // nothing to chain

    // Build vertex pool: unique coordinate keys → index
    const coordKey = (p: Point) => `${p.x},${p.y},${p.z ?? 0}`;
    const vertMap = new Map<string, number>();
    const vertList: Point[] = [];
    const getVert = (p: Point): number => {
      const k = coordKey(p);
      if (!vertMap.has(k)) { vertMap.set(k, vertList.length); vertList.push(p); }
      return vertMap.get(k)!;
    };

    // Build edge list as [vertA, vertB] index pairs
    const edges: [number, number][] = edgePaths.map(p => [getVert(p.points[0]), getVert(p.points[1])]);

    // Degree per vertex
    const degree = new Map<number, number>();
    for (const [a, b] of edges) {
      degree.set(a, (degree.get(a) ?? 0) + 1);
      degree.set(b, (degree.get(b) ?? 0) + 1);
    }

    // Adjacency list
    const adj = new Map<number, number[]>();
    for (const [a, b] of edges) {
      if (!adj.has(a)) adj.set(a, []);
      if (!adj.has(b)) adj.set(b, []);
      adj.get(a)!.push(b);
      adj.get(b)!.push(a);
    }

    const usedEdges = new Set<string>();
    const ek = (a: number, b: number) => `${Math.min(a,b)},${Math.max(a,b)}`;
    const chainedPaths: VecPath[] = [];

    const walkChain = (start: number, firstNext: number, name: string) => {
      const chain: number[] = [start, firstNext];
      usedEdges.add(ek(start, firstNext));
      let cur = firstNext, prev = start;
      while (true) {
        const neighbors = (adj.get(cur) ?? []).filter(n => n !== prev && !usedEdges.has(ek(cur, n)));
        if (neighbors.length === 0) break;
        const d = degree.get(cur) ?? 0;
        if (d === 2 && neighbors.length === 1) {
          // Simple chain continuation — no junction
          usedEdges.add(ek(cur, neighbors[0]));
          chain.push(neighbors[0]);
          prev = cur; cur = neighbors[0];
        } else {
          // Junction (degree > 2): prefer the neighbor that continues the same
          // Z-motion as the incoming edge. This lets coplanar edges chain through
          // junction vertices that also connect to cross-plane edges.
          const dzIn = (vertList[cur].z ?? 0) - (vertList[prev].z ?? 0);
          let bestN = -1, bestScore = Infinity, tie = false;
          for (const n of neighbors) {
            const dzOut = (vertList[n].z ?? 0) - (vertList[cur].z ?? 0);
            const score = Math.abs(dzOut - dzIn);
            if (score < bestScore) { bestScore = score; bestN = n; tie = false; }
            else if (score === bestScore) { tie = true; }
          }
          if (!tie && bestN !== -1) {
            usedEdges.add(ek(cur, bestN));
            chain.push(bestN);
            prev = cur; cur = bestN;
          } else break; // ambiguous junction — stop here
        }
      }
      const closed = chain[0] === chain[chain.length - 1];
      chainedPaths.push({
        name,
        intensity: edgePaths[0]?.intensity ?? 127,
        closed,
        points: chain.map(v => ({ ...vertList[v] })),
      });
    };

    // Start from endpoints/junctions first, then handle closed loops
    const startVerts = [...degree.entries()].filter(([, d]) => d !== 2).map(([v]) => v);
    for (const sv of startVerts) {
      for (const nb of (adj.get(sv) ?? [])) {
        if (!usedEdges.has(ek(sv, nb))) walkChain(sv, nb, `chain_${chainedPaths.length}`);
      }
    }
    for (const [v] of degree) {
      for (const nb of (adj.get(v) ?? [])) {
        if (!usedEdges.has(ek(v, nb))) walkChain(v, nb, `chain_${chainedPaths.length}`);
      }
    }

    const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
    newResource.layers[currentLayerIndex].paths = [...otherPaths, ...chainedPaths];
    updateResource(resource, newResource);
  }, [resource, currentLayerIndex, updateResource]);

  // Mirror vector Y - flip vertically (negate Y coordinates only)
  const mirrorVectorY = useCallback(() => {
    const newResource = { ...resource };

    // Negate only Y coordinates
    newResource.layers.forEach(layer => {
      layer.paths.forEach(path => {
        path.points.forEach(point => {
          point.y = -point.y;
        });
      });
    });

    updateResource(resource, newResource);
  }, [resource, updateResource]);

  // Rotate vector — rotates every point (anchors AND bezier control points,
  // since they all live in `points[]`) around the design-time origin (0,0)
  // by `degrees` degrees, CCW positive in the .vec coord system where +Y is up.
  // Coordinates are rounded back to integers so the output stays Vectrex-safe.
  const rotateVector = useCallback((degrees: number) => {
    const rad = (degrees * Math.PI) / 180;
    const cos = Math.cos(rad);
    const sin = Math.sin(rad);
    const newResource = { ...resource };
    let rotated = 0;
    newResource.layers.forEach(layer => {
      layer.paths.forEach(path => {
        path.points.forEach(point => {
          const x = point.x;
          const y = point.y;
          point.x = Math.round(x * cos - y * sin);
          point.y = Math.round(x * sin + y * cos);
          rotated++;
        });
      });
    });
    // Rotate the background image offset too, so the reference image stays
    // aligned to the sprite after the rotation.
    if (newResource.backgroundOffset) {
      const bx = newResource.backgroundOffset.x;
      const by = newResource.backgroundOffset.y;
      newResource.backgroundOffset = {
        x: Math.round(bx * cos - by * sin),
        y: Math.round(bx * sin + by * cos),
      };
      setBackgroundOffset(newResource.backgroundOffset);
    }
    console.log(`[VectorEditor] Rotated ${rotated} points by ${degrees}°`);
    updateResource(resource, newResource);
  }, [resource, updateResource]);

  // UI Components
  const Toolbar = () => (
    <div style={{ display: 'flex', gap: '4px', marginBottom: '8px', padding: '4px', background: '#2a2a4e', borderRadius: '4px', flexWrap: 'wrap', alignItems: 'center' }}>
      <button
        onClick={() => setCurrentTool('select')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'select' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Select tool - click to select, drag to box select"
      >
        ⬚ Select
      </button>
      <button
        onClick={() => setCurrentTool('pen')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'pen' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Pen tool - click to add points, double-click to finish path"
      >
        ✏️ Pen
      </button>
      <button
        onClick={() => setCurrentTool('pan')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'pan' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title={viewMode === '3d' ? 'Pan/Rotate - drag to rotate 3D view' : 'Pan - drag to move view'}
      >
        {viewMode === '3d' ? '🔄 Rotate' : '✋ Pan'}
      </button>
      <button
        onClick={() => setCurrentTool('walkarea')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'walkarea' ? '#4a8e6a' : '#3a5e4a',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Walkable area — click-drag horizontally to paint a [x_min,x_max] at y (Phase 2 wander AI)"
      >
        🛣️ WalkArea
      </button>
      <button
        onClick={() => setCurrentTool('circle')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'circle' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Circle tool - click center, drag to set radius"
      >
        ⭕ Circle
      </button>
      <button
        onClick={() => setCurrentTool('arc')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'arc' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Arc tool - click center, drag to set radius"
      >
        ◔ Arc
      </button>
      <button
        onClick={() => setCurrentTool('polygon')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'polygon' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Polygon tool - click center, drag to set radius"
      >
        ⬡ Polygon
      </button>
      <button
        onClick={() => setCurrentTool('bezier')}
        style={{
          padding: '8px 12px',
          background: currentTool === 'bezier' ? '#4a4a8e' : '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Bezier tool - click to add sharp anchor, click+drag to add smooth anchor. Enter/Right-click to finish."
      >
        ∿ Bezier
      </button>
      {backgroundImage && (
        <button
          onClick={() => setCurrentTool('background')}
          style={{
            padding: '8px 12px',
            background: currentTool === 'background' ? '#8a6a4a' : '#5a4a3a',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
          title="Move background - drag to reposition the background image"
        >
          🖼️ Move BG
        </button>
      )}
      
      <div style={{ width: '1px', background: '#4a4a6e', margin: '0 8px' }} />
      
      {/* Scale buttons */}
      <button
        onClick={() => {
          console.log('[VectorEditor] Scale Up button clicked');
          handleScale(1.5);
        }}
        style={{
          padding: '8px 12px',
          background: '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Scale up - increase size by 50%"
      >
        🔍+ Scale Up
      </button>
      <button
        onClick={() => {
          console.log('[VectorEditor] Scale Down button clicked');
          handleScale(0.67);
        }}
        style={{
          padding: '8px 12px',
          background: '#3a3a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Scale down - decrease size by 33%"
      >
        🔍- Scale Down
      </button>
      
      <div style={{ width: '1px', background: '#4a4a6e', margin: '0 8px' }} />
      
      {/* Delete button */}
      <button
        onClick={() => {
          if (selectedTreePathKeys.size > 0 || (selectedTreePathKey && selectedPoints.size === 0 && selectedPointIndex < 0)) {
            handleDeleteTreePaths();
          } else {
            handleDeleteSelected();
          }
        }}
        disabled={selectedPoints.size === 0 && selectedPointIndex < 0 && selectedTreePathKeys.size === 0 && !selectedTreePathKey}
        style={{ 
          padding: '8px 12px', 
          background: (selectedPoints.size > 0 || selectedPointIndex >= 0 || selectedTreePathKeys.size > 0 || !!selectedTreePathKey) ? '#8a3a3e' : '#4a4a5e', 
          color: 'white', 
          border: 'none', 
          borderRadius: '4px', 
          cursor: (selectedPoints.size > 0 || selectedPointIndex >= 0 || selectedTreePathKeys.size > 0 || !!selectedTreePathKey) ? 'pointer' : 'not-allowed',
          opacity: (selectedPoints.size > 0 || selectedPointIndex >= 0 || selectedTreePathKeys.size > 0 || !!selectedTreePathKey) ? 1 : 0.5,
        }}
        title="Delete selected points or paths (Delete key)"
      >
        🗑️ Delete {selectedTreePathKeys.size > 1 ? `(${selectedTreePathKeys.size} paths)` : selectedPoints.size > 0 ? `(${selectedPoints.size})` : ''}
      </button>
      
      <div style={{ width: '1px', background: '#4a4a6e', margin: '0 8px' }} />
      
      {/* Undo/Redo buttons */}
      <button
        onClick={handleUndo}
        disabled={historyIndex <= 0}
        style={{
          padding: '8px 12px',
          background: historyIndex > 0 ? '#3a5a3e' : '#4a4a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: historyIndex > 0 ? 'pointer' : 'not-allowed',
          opacity: historyIndex > 0 ? 1 : 0.5,
        }}
        title="Undo (Ctrl+Z / Cmd+Z)"
      >
        ↶ Undo
      </button>
      <button
        onClick={handleRedo}
        disabled={historyIndex >= history.length - 1}
        style={{
          padding: '8px 12px',
          background: historyIndex < history.length - 1 ? '#3a5a3e' : '#4a4a5e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: historyIndex < history.length - 1 ? 'pointer' : 'not-allowed',
          opacity: historyIndex < history.length - 1 ? 1 : 0.5,
        }}
        title="Redo (Ctrl+Shift+Z / Cmd+Shift+Z)"
      >
        ↷ Redo
      </button>
      
      <div style={{ width: '1px', background: '#4a4a6e', margin: '0 8px' }} />

      {/* Transform buttons */}
      <button
        onClick={centerVector}
        style={{
          padding: '8px 12px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Center - move all points so center aligns to (0,0)"
      >
        📍 Center
      </button>
      <button
        onClick={mirrorVectorX}
        style={{
          padding: '8px 12px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Mirror X - flip horizontally (negate X coordinates)"
      >
        ↔️ Mirror X
      </button>
      <button
        onClick={mirrorVectorY}
        style={{
          padding: '8px 12px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Mirror Y - flip vertically (negate Y coordinates)"
      >
        ⇅ Mirror Y
      </button>
      <button
        onClick={() => rotateVector(90)}
        style={{
          padding: '8px 12px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Rotate 90° counter-clockwise around (0,0)"
      >
        ↺ Rotate +90°
      </button>
      <button
        onClick={() => rotateVector(-90)}
        style={{
          padding: '8px 12px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Rotate 90° clockwise around (0,0)"
      >
        ↻ Rotate -90°
      </button>
      <input
        type="number"
        defaultValue={15}
        step={1}
        title="Custom rotation angle (degrees, CCW positive)"
        style={{
          width: '48px',
          padding: '6px 4px',
          background: '#1a1a2a',
          color: 'white',
          border: '1px solid #3a5a3e',
          borderRadius: '4px',
          fontSize: '12px',
        }}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            const v = parseFloat((e.target as HTMLInputElement).value);
            if (!Number.isNaN(v) && v !== 0) rotateVector(v);
          }
        }}
        id="rotate-angle-input"
      />
      <button
        onClick={() => {
          const inp = document.getElementById('rotate-angle-input') as HTMLInputElement | null;
          const v = inp ? parseFloat(inp.value) : NaN;
          if (!Number.isNaN(v) && v !== 0) rotateVector(v);
        }}
        style={{
          padding: '8px 10px',
          background: '#3a5a3e',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
        }}
        title="Rotate by the angle in the input (positive = CCW)"
      >
        🔁 Rotate
      </button>
      <button
        onClick={chainEdges}
        style={{ padding: '8px 12px', background: '#3a5a3e', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        title="Chain edges — merge 2-point paths that share endpoints into polylines, reducing path count"
      >
        🔗 Chain Edges
      </button>
      <button
        onClick={() => handleSimplify(2.0)}
        style={{ padding: '8px 12px', background: '#5a3a2e', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        title="Simplify paths (ε=2) — Ramer-Douglas-Peucker: removes near-collinear points invisible at Vectrex scale. Undoable with Ctrl+Z."
      >
        ✂️ Simplify
      </button>

      <div style={{ width: '1px', background: '#4a4a6e', margin: '0 8px' }} />
      
      <button
        onClick={() => fileInputRef.current?.click()}
        style={{ padding: '8px 12px', background: '#3a5a3e', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
      >
        📷 Load Image
      </button>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleImageUpload}
        style={{ display: 'none' }}
      />
      <button
        onClick={() => dxfInputRef.current?.click()}
        style={{ padding: '8px 12px', background: '#3a4a5a', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        title="Import DXF geometry as new paths on current layer"
      >
        📐 Import DXF
      </button>
      <input
        ref={dxfInputRef}
        type="file"
        accept=".dxf"
        onChange={handleDxfImport}
        style={{ display: 'none' }}
      />
      <button
        onClick={() => objInputRef.current?.click()}
        style={{ padding: '8px 12px', background: '#3a4a5a', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        title="Import OBJ 3D mesh wireframe as paths (Fusion 360, Blender, etc.)"
      >
        📦 Import OBJ
      </button>
      <input
        ref={objInputRef}
        type="file"
        accept=".obj"
        onChange={handleObjImport}
        style={{ display: 'none' }}
      />

      {backgroundImage && (
        <>
          <button
            onClick={() => setShowBackground(!showBackground)}
            style={{
              padding: '8px 12px',
              background: showBackground ? '#4a4a8e' : '#3a3a5e',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
            }}
          >
            {showBackground ? '👁 Hide' : '👁 Show'}
          </button>
          <button
            onClick={handleAutoDetect}
            disabled={isProcessing}
            style={{
              padding: '8px 12px',
              background: isProcessing ? '#666' : '#5a3a8e',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: isProcessing ? 'wait' : 'pointer',
            }}
          >
            {isProcessing ? '⏳ Processing...' : '✨ Auto-Trace'}
          </button>
          <button
            onClick={() => setShowEdgeSettings(!showEdgeSettings)}
            style={{
              padding: '8px 12px',
              background: showEdgeSettings ? '#4a4a8e' : '#3a3a5e',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
            }}
          >
            ⚙️
          </button>
        </>
      )}
      
      <div style={{ flex: 1 }} />
      
      <button
        onClick={() => setZoom(z => Math.min(z * 1.2, 16))}
        style={{ padding: '8px 12px', background: '#3a3a5e', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
      >
        +
      </button>
      <button
        onClick={() => setZoom(z => Math.max(z / 1.2, 0.5))}
        style={{ padding: '8px 12px', background: '#3a3a5e', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
      >
        -
      </button>
      <span style={{ color: '#aaa', padding: '8px' }}>{Math.round(zoom * 100)}%</span>
    </div>
  );

  const CircleArcSettings = () => {
    if (currentTool !== 'circle' && currentTool !== 'arc' && currentTool !== 'polygon') return null;
    
    return (
      <div style={{ background: '#2a2a4e', padding: '10px', borderRadius: '4px', marginBottom: '8px' }}>
        <div style={{ display: 'flex', gap: '16px', alignItems: 'center', flexWrap: 'wrap' }}>
          {(currentTool === 'circle' || currentTool === 'arc') && (
          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#aaa', fontSize: '12px' }}>
            <span>Segments:</span>
            <input
              type="number"
              min="3"
              max="64"
              value={circleSegments}
              onChange={(e) => setCircleSegments(Math.max(3, Math.min(64, parseInt(e.target.value) || 8)))}
              style={{
                width: '60px',
                padding: '4px',
                background: '#1a1a3e',
                color: 'white',
                border: '1px solid #4a4a6e',
                borderRadius: '4px',
              }}
            />
          </label>
          )}
          
          {currentTool === 'polygon' && (
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#aaa', fontSize: '12px' }}>
              <span>Sides:</span>
              <input
                type="number"
                min="3"
                max="32"
                value={polygonSides}
                onChange={(e) => setPolygonSides(Math.max(3, Math.min(32, parseInt(e.target.value) || 6)))}
                style={{
                  width: '60px',
                  padding: '4px',
                  background: '#1a1a3e',
                  color: 'white',
                  border: '1px solid #4a4a6e',
                  borderRadius: '4px',
                }}
              />
            </label>
          )}
          {currentTool === 'arc' && (
            <>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#aaa', fontSize: '12px' }}>
                <span>Start Angle (°):</span>
                <input
                  type="number"
                  min="0"
                  max="360"
                  value={arcStartAngle}
                  onChange={(e) => setArcStartAngle(parseInt(e.target.value) || 0)}
                  style={{
                    width: '60px',
                    padding: '4px',
                    background: '#1a1a3e',
                    color: 'white',
                    border: '1px solid #4a4a6e',
                    borderRadius: '4px',
                  }}
                />
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#aaa', fontSize: '12px' }}>
                <span>End Angle (°):</span>
                <input
                  type="number"
                  min="0"
                  max="360"
                  value={arcEndAngle}
                  onChange={(e) => setArcEndAngle(parseInt(e.target.value) || 180)}
                  style={{
                    width: '60px',
                    padding: '4px',
                    background: '#1a1a3e',
                    color: 'white',
                    border: '1px solid #4a4a6e',
                    borderRadius: '4px',
                  }}
                />
              </label>
            </>
          )}
          
          <div style={{ color: '#888', fontSize: '11px' }}>
            {currentTool === 'circle' 
              ? `Click center, drag to set radius. ${circleSegments} segments.`
              : currentTool === 'polygon'
              ? `Click center, drag to set radius. ${polygonSides}-sided polygon.`
              : `Click center, drag to set radius. Arc from ${arcStartAngle}° to ${arcEndAngle}° (${circleSegments} segments).`
            }
          </div>
        </div>
      </div>
    );
  };

  const EdgeSettingsPanel = () => {
    const previewPointCount = previewPaths.reduce((sum, p) => sum + p.points.length, 0);
    
    return showEdgeSettings && backgroundImage ? (
      <div style={{ background: '#2a2a4e', padding: '10px', borderRadius: '4px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
          <div style={{ color: '#aaa', fontSize: '11px', fontWeight: 'bold' }}>Auto-Trace</div>
          <label style={{ display: 'flex', alignItems: 'center', gap: '4px', color: '#888', fontSize: '10px', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={showPreview}
              onChange={(e) => setShowPreview(e.target.checked)}
              style={{ margin: 0 }}
            />
            Preview
          </label>
        </div>
        
        {/* Preview stats */}
        {showPreview && previewPaths.length > 0 && (
          <div style={{ 
            background: '#3a3a5e', 
            padding: '8px', 
            borderRadius: '4px', 
            marginBottom: '12px',
            color: '#ff88ff',
            fontSize: '11px',
            display: 'flex',
            justifyContent: 'space-between'
          }}>
            <span>📊 {previewPaths.length} paths</span>
            <span>{previewPointCount} points</span>
          </div>
        )}
        
        <div style={{ marginBottom: '8px' }}>
          <label style={{ color: '#888', fontSize: '10px', display: 'block', marginBottom: '2px' }}>
            Opacity: {Math.round(backgroundOpacity * 100)}%
          </label>
          <input
            type="range"
            min="0"
            max="100"
            step="5"
            value={backgroundOpacity * 100}
            onChange={(e) => setBackgroundOpacity(parseInt(e.target.value) / 100)}
            style={{ width: '100%', cursor: 'pointer', height: '16px' }}
          />
        </div>
        
        <div style={{ marginBottom: '8px' }}>
          <label style={{ color: '#888', fontSize: '10px', display: 'block', marginBottom: '2px' }}>
            Low: {edgeOptions.lowThreshold}
          </label>
          <input
            type="range"
            min="5"
            max="100"
            step="5"
            value={edgeOptions.lowThreshold}
            onChange={(e) => setEdgeOptions({ ...edgeOptions, lowThreshold: parseInt(e.target.value) })}
            style={{ width: '100%', cursor: 'pointer', height: '16px' }}
          />
        </div>
        
        <div style={{ marginBottom: '8px' }}>
          <label style={{ color: '#888', fontSize: '10px', display: 'block', marginBottom: '2px' }}>
            High: {edgeOptions.highThreshold}
          </label>
          <input
            type="range"
            min="20"
            max="200"
            step="5"
            value={edgeOptions.highThreshold}
            onChange={(e) => setEdgeOptions({ ...edgeOptions, highThreshold: parseInt(e.target.value) })}
            style={{ width: '100%', cursor: 'pointer', height: '16px' }}
          />
        </div>
        
        <div style={{ marginBottom: '8px' }}>
          <label style={{ color: '#888', fontSize: '10px', display: 'block', marginBottom: '2px' }}>
            Simplify: {edgeOptions.simplifyTolerance}
          </label>
          <input
            type="range"
            min="1"
            max="20"
            step="1"
            value={edgeOptions.simplifyTolerance}
            onChange={(e) => setEdgeOptions({ ...edgeOptions, simplifyTolerance: parseInt(e.target.value) })}
            style={{ width: '100%', cursor: 'pointer', height: '16px' }}
          />
        </div>
        
        <div style={{ marginBottom: '8px' }}>
          <label style={{ color: '#888', fontSize: '10px', display: 'block', marginBottom: '2px' }}>
            Min Length: {edgeOptions.minPathLength}
          </label>
          <input
            type="range"
            min="2"
            max="30"
            step="2"
            value={edgeOptions.minPathLength}
            onChange={(e) => setEdgeOptions({ ...edgeOptions, minPathLength: parseInt(e.target.value) })}
            style={{ width: '100%', cursor: 'pointer', height: '16px' }}
          />
        </div>
        
        {/* Blur toggle */}
        <div style={{ marginBottom: '8px' }}>
          <label style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#888', fontSize: '10px', cursor: 'pointer' }}>
            <input
              type="checkbox"
              checked={edgeOptions.useBlur}
              onChange={(e) => setEdgeOptions({ ...edgeOptions, useBlur: e.target.checked })}
              style={{ margin: 0 }}
            />
            Blur (photos)
          </label>
        </div>
        
        {/* Buttons row */}
        <div style={{ display: 'flex', gap: '6px' }}>
          {/* Reset button */}
          <button
            onClick={() => setEdgeOptions(defaultEdgeOptions)}
            style={{
              flex: 1,
              padding: '6px',
              background: '#5a4a3e',
              color: '#fa8',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '10px',
            }}
            title="Reset to default values"
          >
            ↺ Reset
          </button>
          
          {/* Apply button */}
          <button
            onClick={handleAutoDetect}
            disabled={isProcessing || previewPaths.length === 0}
            style={{
              flex: 2,
              padding: '6px',
              background: previewPaths.length > 0 ? '#4a8a4e' : '#4a4a5e',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: previewPaths.length > 0 ? 'pointer' : 'not-allowed',
              fontSize: '10px',
              fontWeight: 'bold',
            }}
          >
            {isProcessing ? '⏳...' : `✓ (${previewPaths.length})`}
          </button>
        </div>
      </div>
    ) : null;
  };

  const LayersPanel = () => {
    const toggleLayerVisible = (layerIdx: number) => {
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      newResource.layers[layerIdx].visible = !newResource.layers[layerIdx].visible;
      updateResource(resource, newResource);
    };

    const addLayer = () => {
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      const n = newResource.layers.length + 1;
      newResource.layers.push({ name: `layer_${n}`, visible: true, paths: [] });
      updateResource(resource, newResource);
      setCurrentLayerIndex(newResource.layers.length - 1);
    };

    const deleteLayer = (layerIdx: number) => {
      if (resource.layers.length <= 1) return; // keep at least one
      if (!window.confirm(`Delete layer "${resource.layers[layerIdx].name}"?`)) return;
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      newResource.layers.splice(layerIdx, 1);
      updateResource(resource, newResource);
      setCurrentLayerIndex(Math.min(currentLayerIndex, newResource.layers.length - 1));
    };

    return (
      <div style={{ background: '#2a2a4e', padding: '8px', borderRadius: '4px' }}>
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: '8px' }}>
          <div style={{ color: '#aaa', fontSize: '12px', fontWeight: 'bold', flex: 1 }}>Layers</div>
          <button
            onClick={addLayer}
            title="Add layer"
            style={{ background: '#3a5a3a', border: '1px solid #5a8a5a', color: '#8f8', borderRadius: '3px', cursor: 'pointer', fontSize: '14px', lineHeight: 1, padding: '1px 6px' }}
          >+</button>
        </div>

        {/* Background image pseudo-layer */}
        {backgroundImage && (
          <div style={{ padding: '6px 8px', background: '#3a4a3e', color: '#8f8', borderRadius: '4px', marginBottom: '4px', fontSize: '11px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <input type="checkbox" checked={showBackground} onChange={(e) => setShowBackground(e.target.checked)} style={{ margin: 0 }} />
              <span>📷 Background</span>
              <button
                onClick={() => { if (window.confirm('Remove background image?')) { setBackgroundImage(null); setShowBackground(false); setShowEdgeSettings(false); const nr = { ...resource }; delete nr.backgroundImage; updateResource(resource, nr); } }}
                style={{ marginLeft: 'auto', background: 'transparent', border: 'none', color: '#a66', cursor: 'pointer', fontSize: '12px', padding: '2px 4px' }}
              >✕</button>
            </div>
          </div>
        )}

        {/* All vector layers + path tree */}
        {resource.layers.map((layer, layerIdx) => {
          const isActive = layerIdx === currentLayerIndex;
          const pathCount = layer.paths.length;
          const pointCount = layer.paths.reduce((s, p) => s + p.points.length, 0);
          return (
            <div key={layerIdx} style={{ marginBottom: '4px' }}>
              {/* Layer row */}
              <div
                onClick={() => { setCurrentLayerIndex(layerIdx); setSelectedPoints(new Set()); setCurrentPathIndex(-1); setSelectedPointIndex(-1); }}
                style={{ padding: '6px 8px', background: isActive ? '#4a4a8e' : '#2e2e4e', color: isActive ? 'white' : '#aaa', borderRadius: '4px', fontSize: '12px', cursor: 'pointer', border: isActive ? '1px solid #7a7abf' : '1px solid transparent' }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <input
                    type="checkbox"
                    checked={layer.visible !== false}
                    onChange={(e) => { e.stopPropagation(); toggleLayerVisible(layerIdx); }}
                    style={{ margin: 0 }}
                    title="Toggle visibility"
                  />
                  <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{layer.name}</span>
                  {isActive && <span style={{ color: '#7af', fontSize: '9px', flexShrink: 0 }}>active</span>}
                  {resource.layers.length > 1 && (
                    <button
                      onClick={(e) => { e.stopPropagation(); deleteLayer(layerIdx); }}
                      title="Delete layer"
                      style={{ background: 'transparent', border: 'none', color: '#a66', cursor: 'pointer', fontSize: '11px', padding: '0 2px', flexShrink: 0 }}
                    >✕</button>
                  )}
                </div>
                <div style={{ color: '#666', fontSize: '10px', marginTop: '2px' }}>
                  {pathCount} path{pathCount !== 1 ? 's' : ''} · {pointCount} pt{pointCount !== 1 ? 's' : ''}
                  {pathCount > 0 && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        setCollapsedLayerPaths(prev => {
                          const next = new Set(prev);
                          if (next.has(layerIdx)) next.delete(layerIdx);
                          else next.add(layerIdx);
                          return next;
                        });
                      }}
                      style={{ marginLeft: '6px', background: 'transparent', border: 'none', color: '#556', cursor: 'pointer', fontSize: '9px', padding: '0', lineHeight: 1 }}
                      title={collapsedLayerPaths.has(layerIdx) ? 'Show paths' : 'Hide paths'}
                    >{collapsedLayerPaths.has(layerIdx) ? '▶ show' : '▼ hide'}</button>
                  )}
                </div>
              </div>

              {/* Path tree — only shown when layer is active and not collapsed */}
              {isActive && layer.paths.length > 0 && !collapsedLayerPaths.has(layerIdx) && (
                <div style={{ marginLeft: '12px', marginTop: '2px' }}>
                  {layer.paths.map((p, pathIdx) => {
                    const treeKey = `${layerIdx}-${pathIdx}`;
                    const isTreeSelected = selectedTreePathKeys.has(treeKey) || selectedTreePathKey === treeKey;
                    const isExpanded = expandedTreePaths.has(treeKey);
                    return (
                      <div key={pathIdx}>
                        {/* Path row */}
                        <div
                          onClick={(e) => {
                            e.stopPropagation();
                            if (e.ctrlKey || e.metaKey) {
                              // Ctrl/Cmd+Click: toggle in multi-selection
                              setSelectedTreePathKeys(prev => {
                                const next = new Set(prev);
                                if (next.has(treeKey)) next.delete(treeKey);
                                else next.add(treeKey);
                                return next;
                              });
                              setSelectedTreePathKey(treeKey);
                            } else {
                              setSelectedTreePathKey(isTreeSelected && selectedTreePathKeys.size <= 1 ? null : treeKey);
                              setSelectedTreePathKeys(isTreeSelected && selectedTreePathKeys.size <= 1 ? new Set() : new Set([treeKey]));
                            }
                            setCurrentLayerIndex(layerIdx);
                            setCurrentPathIndex(pathIdx);
                            setSelectedPointIndex(-1);
                            setSelectedPoints(new Set());
                          }}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                            padding: '3px 6px',
                            background: isTreeSelected ? '#1a4a5a' : 'transparent',
                            color: isTreeSelected ? '#00ffff' : '#99aaaa',
                            borderRadius: '3px',
                            fontSize: '11px',
                            cursor: 'pointer',
                            border: isTreeSelected ? '1px solid #007090' : '1px solid transparent',
                            marginBottom: '1px',
                          }}
                        >
                          {/* Expand toggle */}
                          <span
                            onClick={(e) => {
                              e.stopPropagation();
                              setExpandedTreePaths(prev => {
                                const next = new Set(prev);
                                if (next.has(treeKey)) next.delete(treeKey);
                                else next.add(treeKey);
                                return next;
                              });
                            }}
                            style={{ fontSize: '9px', width: '10px', flexShrink: 0, opacity: 0.7, userSelect: 'none' }}
                          >
                            {isExpanded ? '▼' : '▶'}
                          </span>
                          <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {p.name || `path_${pathIdx}`}
                          </span>
                          <span style={{ color: '#556', fontSize: '9px', flexShrink: 0 }}>
                            {p.points.length}pt
                          </span>
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              const nr = JSON.parse(JSON.stringify(resource)) as VecResource;
                              nr.layers[layerIdx].paths.splice(pathIdx, 1);
                              updateResource(resource, nr);
                              setSelectedTreePathKey(prev => prev === treeKey ? null : prev);
                              setSelectedTreePathKeys(prev => { const next = new Set(prev); next.delete(treeKey); return next; });
                              if (currentPathIndex === pathIdx && currentLayerIndex === layerIdx) setCurrentPathIndex(-1);
                            }}
                            title="Delete this path"
                            style={{ background: 'transparent', border: 'none', color: '#a55', cursor: 'pointer', fontSize: '10px', padding: '0 2px', flexShrink: 0, lineHeight: 1 }}
                          >✕</button>
                        </div>

                        {/* Point sub-rows */}
                        {isExpanded && (
                          <div style={{ marginLeft: '16px' }}>
                            {p.points.map((pt, ptIdx) => (
                              <div
                                key={ptIdx}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  setCurrentLayerIndex(layerIdx);
                                  setCurrentPathIndex(pathIdx);
                                  setSelectedPointIndex(ptIdx);
                                  setSelectedPoints(new Set());
                                  setSelectedTreePathKey(treeKey);
                                }}
                                style={{
                                  padding: '2px 4px',
                                  fontSize: '10px',
                                  color: selectedPointIndex === ptIdx && currentPathIndex === pathIdx ? '#ffff00' : '#667',
                                  cursor: 'pointer',
                                  borderRadius: '2px',
                                  background: selectedPointIndex === ptIdx && currentPathIndex === pathIdx ? '#3a3a1a' : 'transparent',
                                  whiteSpace: 'nowrap',
                                  overflow: 'hidden',
                                  textOverflow: 'ellipsis',
                                }}
                              >
                                {ptIdx}: ({pt.x}, {pt.y}{pt.z !== undefined ? `, ${pt.z}` : ''})
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}

        {/* Selection info */}
        {selectedPoints.size > 0 && (
          <div style={{ marginTop: '8px', padding: '6px 8px', background: '#5a3a3e', color: '#faa', borderRadius: '4px', fontSize: '11px' }}>
            {selectedPoints.size} point{selectedPoints.size !== 1 ? 's' : ''} selected
          </div>
        )}
      </div>
    );
  };

  // Path properties panel - shows when a path is selected
  const PathPropertiesPanel = () => {
    if (currentPathIndex < 0) return null;
    
    const activeLayer = resource.layers[currentLayerIndex];
    if (!activeLayer || !activeLayer.paths[currentPathIndex]) return null;
    
    const path = activeLayer.paths[currentPathIndex];
    
    const handleIntensityChange = (newIntensity: number) => {
      const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
      if (newResource.layers[currentLayerIndex] && newResource.layers[currentLayerIndex].paths[currentPathIndex]) {
        newResource.layers[currentLayerIndex].paths[currentPathIndex].intensity = newIntensity;
        updateResource(resource, newResource);
      }
    };
    
    return (
      <div style={{ background: '#2a2a4e', padding: '8px', borderRadius: '4px', marginTop: '8px' }}>
        <div style={{ color: '#6af', marginBottom: '8px', fontSize: '12px', fontWeight: 'bold' }}>
          Path {currentPathIndex + 1} Properties
        </div>
        
        <div style={{ marginBottom: '8px' }}>
          <div style={{ color: '#aaa', fontSize: '11px', marginBottom: '4px' }}>
            Intensity: <strong>{path.intensity}</strong>
          </div>
          <input
            type="range"
            min="0"
            max="127"
            value={path.intensity}
            onChange={(e) => handleIntensityChange(parseInt(e.target.value))}
            style={{
              width: '100%',
              cursor: 'pointer',
            }}
            title="Adjust path intensity (brightness)"
          />
          <div style={{ display: 'flex', gap: '4px', marginTop: '4px', fontSize: '10px' }}>
            <button
              onClick={() => handleIntensityChange(Math.max(0, path.intensity - 10))}
              style={{
                flex: 1,
                padding: '4px',
                background: '#3a5a3a',
                border: '1px solid #5a8a5a',
                color: '#aaa',
                borderRadius: '3px',
                cursor: 'pointer',
              }}
            >
              -10
            </button>
            <button
              onClick={() => handleIntensityChange(127)}
              style={{
                flex: 1,
                padding: '4px',
                background: '#4a4a7e',
                border: '1px solid #6a6aae',
                color: '#aaa',
                borderRadius: '3px',
                cursor: 'pointer',
              }}
            >
              Max
            </button>
            <button
              onClick={() => handleIntensityChange(Math.min(127, path.intensity + 10))}
              style={{
                flex: 1,
                padding: '4px',
                background: '#5a3a3a',
                border: '1px solid #8a5a5a',
                color: '#aaa',
                borderRadius: '3px',
                cursor: 'pointer',
              }}
            >
              +10
            </button>
          </div>
        </div>

        {/* Collision Mesh section */}
        <div style={{ marginTop: '10px', borderTop: '1px solid #444', paddingTop: '8px' }}>
          <div style={{ color: '#c8a', marginBottom: '6px', fontSize: '12px', fontWeight: 'bold' }}>
            Collision Mesh
          </div>
          <div style={{ display: 'flex', gap: '4px', marginBottom: '6px', flexWrap: 'wrap' }}>
            <button
              onClick={() => {
                const segs = generateMeshFromPath(path);
                const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
                newResource.collisionMesh = { segments: segs };
                updateResource(resource, newResource);
                setShowCollisionMesh(true);
              }}
              style={{
                flex: 1,
                padding: '5px 4px',
                background: '#3a3a6a',
                border: '1px solid #6060aa',
                color: '#ccf',
                borderRadius: '3px',
                cursor: 'pointer',
                fontSize: '10px',
              }}
              title="Auto-generate collision mesh from horizontal edges of selected path"
            >
              Auto-generate
            </button>
            <button
              onClick={() => {
                if (!selectedEdge) return;
                const selPath = resource.layers[currentLayerIndex]?.paths[selectedEdge.pathIdx];
                if (!selPath) return;
                const p1 = selPath.points[selectedEdge.edgeIdx];
                const p2 = selPath.points[selectedEdge.edgeIdx + 1];
                if (!p1 || !p2) return;
                const newSeg: CollisionSegment = {
                  x1: Math.round(p1.x), y1: Math.round(p1.y),
                  x2: Math.round(p2.x), y2: Math.round(p2.y),
                };
                const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
                if (!newResource.collisionMesh) newResource.collisionMesh = { segments: [] };
                newResource.collisionMesh.segments.push(newSeg);
                updateResource(resource, newResource);
                setShowCollisionMesh(true);
              }}
              disabled={!selectedEdge}
              style={{
                flex: 1,
                padding: '5px 4px',
                background: selectedEdge ? '#3a5a3a' : '#2a2a2a',
                border: selectedEdge ? '1px solid #5a9a5a' : '1px solid #444',
                color: selectedEdge ? '#afa' : '#666',
                borderRadius: '3px',
                cursor: selectedEdge ? 'pointer' : 'default',
                fontSize: '10px',
              }}
              title="Add the selected edge (orange) to the collision mesh"
            >
              + Edge
            </button>
            <button
              onClick={() => {
                const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
                newResource.collisionMesh = { segments: [] };
                updateResource(resource, newResource);
              }}
              disabled={!resource.collisionMesh?.segments?.length}
              style={{
                padding: '5px 6px',
                background: '#4a2a2a',
                border: '1px solid #8a4a4a',
                color: '#faa',
                borderRadius: '3px',
                cursor: 'pointer',
                fontSize: '10px',
                opacity: resource.collisionMesh?.segments?.length ? 1 : 0.4,
              }}
              title="Clear collision mesh"
            >
              Clear
            </button>
            <button
              onClick={() => setShowCollisionMesh(v => !v)}
              style={{
                padding: '5px 6px',
                background: showCollisionMesh ? '#3a5a3a' : '#2a2a2a',
                border: showCollisionMesh ? '1px solid #5a9a5a' : '1px solid #555',
                color: showCollisionMesh ? '#afa' : '#888',
                borderRadius: '3px',
                cursor: 'pointer',
                fontSize: '10px',
              }}
              title="Toggle collision mesh overlay on canvas"
            >
              {showCollisionMesh ? '👁 On' : '👁 Off'}
            </button>
          </div>
          {selectedEdge !== null && (() => {
            const selPath = resource.layers[currentLayerIndex]?.paths[selectedEdge.pathIdx];
            const p1 = selPath?.points[selectedEdge.edgeIdx];
            const p2 = selPath?.points[selectedEdge.edgeIdx + 1];
            return p1 && p2 ? (
              <div style={{ fontSize: '9px', color: '#ffaa00', fontFamily: 'monospace', marginBottom: '4px' }}>
                Edge: ({Math.round(p1.x)},{Math.round(p1.y)})→({Math.round(p2.x)},{Math.round(p2.y)})
              </div>
            ) : null;
          })()}
          <div style={{ fontSize: '10px', color: '#999' }}>
            {resource.collisionMesh?.segments?.length
              ? `${resource.collisionMesh.segments.length} segment${resource.collisionMesh.segments.length !== 1 ? 's' : ''}`
              : 'No mesh — click Auto-generate or select an edge'}
          </div>
          {resource.collisionMesh?.segments?.map((seg, idx) => (
            <div key={idx} style={{
              fontSize: '9px', color: '#c8a', fontFamily: 'monospace',
              marginTop: '2px', display: 'flex', alignItems: 'center', gap: '4px'
            }}>
              <span style={{ flex: 1 }}>
                ({seg.x1},{seg.y1})→({seg.x2},{seg.y2})
              </span>
              <button
                onClick={() => {
                  const newResource = JSON.parse(JSON.stringify(resource)) as VecResource;
                  newResource.collisionMesh!.segments.splice(idx, 1);
                  updateResource(resource, newResource);
                }}
                style={{
                  padding: '1px 4px', background: 'transparent',
                  border: '1px solid #666', color: '#f88', borderRadius: '2px',
                  cursor: 'pointer', fontSize: '9px',
                }}
              >x</button>
            </div>
          ))}
        </div>

        {/* Walkable Areas section: stored on the .vec itself and inherited
            by every level placement of this asset (.vec → .vplay → .venemy). */}
        <div style={{ marginTop: '10px', borderTop: '1px solid #444', paddingTop: '8px' }}>
          <div style={{ color: '#4fc', marginBottom: '6px', fontSize: '12px', fontWeight: 'bold' }}>
            Walkable Areas
          </div>
          <div style={{ fontSize: '10px', color: '#999', marginBottom: '6px' }}>
            {resource.walkableAreas?.length
              ? `${resource.walkableAreas.length} area${resource.walkableAreas.length !== 1 ? 's' : ''} — pick 🛣️ WalkArea to add more`
              : 'No areas — pick 🛣️ WalkArea and drag horizontally to paint'}
          </div>
          {(resource.walkableAreas ?? []).map((a, idx) => (
            <div key={idx} style={{
              fontSize: '9px', color: '#4fc', fontFamily: 'monospace',
              marginTop: '2px', display: 'flex', alignItems: 'center', gap: '4px'
            }}>
              <span style={{ flex: 1 }}>
                W{idx}: y={a.y}, x=[{a.x_min},{a.x_max}]
              </span>
              <button
                onClick={() => {
                  const next = (resource.walkableAreas ?? []).slice();
                  next.splice(idx, 1);
                  updateResource(resource, { ...resource, walkableAreas: next });
                }}
                style={{
                  padding: '1px 4px', background: 'transparent',
                  border: '1px solid #666', color: '#f88', borderRadius: '2px',
                  cursor: 'pointer', fontSize: '9px',
                }}
              >x</button>
            </div>
          ))}
          {(resource.walkableAreas?.length ?? 0) > 0 && (
            <button
              onClick={() => updateResource(resource, { ...resource, walkableAreas: [] })}
              style={{
                marginTop: '6px', padding: '4px 8px', background: '#4a2a2a',
                border: '1px solid #8a4a4a', color: '#faa', borderRadius: '3px',
                cursor: 'pointer', fontSize: '10px',
              }}
            >Clear all</button>
          )}
        </div>

        <div style={{ fontSize: '11px', color: '#888' }}>
          <div>Points: {path.points.length}</div>
          <div>Closed: {path.closed ? 'Yes' : 'No'}</div>
          <div style={{ marginTop: '4px', color: '#666' }}>{path.name}</div>
        </div>
      </div>
    );
  };

  // ViewCube component - 3D cube visualization like Fusion 360
  const ViewCube = () => {
    const cubeCanvasRef = useRef<HTMLCanvasElement>(null);
    const cubeSize = 100;
    const [hoveredFace, setHoveredFace] = useState<ViewMode | null>(null);
    
    // Draw the 3D cube
    useEffect(() => {
      const canvas = cubeCanvasRef.current;
      if (!canvas) return;
      
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      
      // Clear
      ctx.clearRect(0, 0, cubeSize, cubeSize);
      
      const centerX = cubeSize / 2;
      const centerY = cubeSize / 2;
      const size = 30;
      
      // Calculate cube rotation based on current view
      let rotX = 30, rotY = 30;
      if (viewMode === 'xy') { rotX = 0; rotY = 0; }
      else if (viewMode === 'xz') { rotX = 90; rotY = 0; }
      else if (viewMode === 'yz') { rotX = 0; rotY = 90; }
      else { rotX = rotation3D.pitch; rotY = rotation3D.yaw; }
      
      const rad = Math.PI / 180;
      const cosX = Math.cos(rotX * rad);
      const sinX = Math.sin(rotX * rad);
      const cosY = Math.cos(rotY * rad);
      const sinY = Math.sin(rotY * rad);
      
      // Project 3D point to 2D
      const project = (x: number, y: number, z: number) => {
        // Rotate Y
        let x1 = x * cosY - z * sinY;
        let z1 = x * sinY + z * cosY;
        // Rotate X
        let y1 = y * cosX - z1 * sinX;
        let z2 = y * sinX + z1 * cosX;
        // Project
        return { x: centerX + x1, y: centerY - y1, z: z2 };
      };
      
      // Cube vertices
      const vertices = [
        project(-size, -size, -size),
        project(size, -size, -size),
        project(size, size, -size),
        project(-size, size, -size),
        project(-size, -size, size),
        project(size, -size, size),
        project(size, size, size),
        project(-size, size, size),
      ];
      
      // Define faces with their view mode
      const faces = [
        { indices: [4, 5, 6, 7], color: '#4a4a8e', view: 'xy' as ViewMode, label: 'TOP', normal: [0, 0, 1] },
        { indices: [0, 1, 2, 3], color: '#3a3a6e', view: 'xy' as ViewMode, label: 'BOT', normal: [0, 0, -1] },
        { indices: [0, 1, 5, 4], color: '#4a6a4e', view: 'xz' as ViewMode, label: 'FRT', normal: [0, -1, 0] },
        { indices: [3, 2, 6, 7], color: '#3a5a3e', view: 'xz' as ViewMode, label: 'BAK', normal: [0, 1, 0] },
        { indices: [1, 2, 6, 5], color: '#6a4a4e', view: 'yz' as ViewMode, label: 'RGT', normal: [1, 0, 0] },
        { indices: [0, 3, 7, 4], color: '#5a3a3e', view: 'yz' as ViewMode, label: 'LFT', normal: [-1, 0, 0] },
      ];
      
      // Sort faces by average Z (painter's algorithm)
      faces.sort((a, b) => {
        const avgZa = a.indices.reduce((sum, i) => sum + vertices[i].z, 0) / 4;
        const avgZb = b.indices.reduce((sum, i) => sum + vertices[i].z, 0) / 4;
        return avgZa - avgZb;
      });
      
      // Draw faces
      faces.forEach(face => {
        const isActive = face.view === viewMode;
        const isHovered = face.view === hoveredFace;
        
        ctx.beginPath();
        const first = vertices[face.indices[0]];
        ctx.moveTo(first.x, first.y);
        for (let i = 1; i < face.indices.length; i++) {
          const v = vertices[face.indices[i]];
          ctx.lineTo(v.x, v.y);
        }
        ctx.closePath();
        
        // Fill
        ctx.fillStyle = isActive ? '#6a6aae' : isHovered ? '#5a5a8e' : face.color;
        ctx.fill();
        
        // Stroke
        ctx.strokeStyle = isActive ? '#8a8ace' : '#2a2a4e';
        ctx.lineWidth = isActive ? 2 : 1;
        ctx.stroke();
        
        // Label
        const centerFaceX = face.indices.reduce((sum, i) => sum + vertices[i].x, 0) / 4;
        const centerFaceY = face.indices.reduce((sum, i) => sum + vertices[i].y, 0) / 4;
        ctx.fillStyle = isActive ? 'white' : '#aaa';
        ctx.font = 'bold 9px monospace';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(face.label, centerFaceX, centerFaceY);
      });
      
    }, [viewMode, rotation3D, hoveredFace]);
    
    // Detect clicks on cube faces
    const handleCubeClick = (e: React.MouseEvent<HTMLCanvasElement>) => {
      const canvas = cubeCanvasRef.current;
      if (!canvas) return;
      
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      // Simple click detection based on regions (could be improved with actual face hit testing)
      const centerX = cubeSize / 2;
      const centerY = cubeSize / 2;
      
      if (y < centerY - 10) setViewMode('xy'); // Top
      else if (y > centerY + 10) setViewMode('xz'); // Front
      else if (x > centerX + 10) setViewMode('yz'); // Right
      else setViewMode('3d'); // Center = 3D
    };
    
    return (
      <div
        style={{
          position: 'absolute',
          top: '16px',
          right: '16px',
          background: 'rgba(26, 26, 46, 0.95)',
          border: '2px solid #4a4a6e',
          borderRadius: '8px',
          padding: '8px',
          zIndex: 1000,
          boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
        }}
      >
        <canvas
          ref={cubeCanvasRef}
          width={cubeSize}
          height={cubeSize}
          onClick={handleCubeClick}
          onMouseMove={(e) => {
            // Simplified hover detection
            const rect = e.currentTarget.getBoundingClientRect();
            const y = e.clientY - rect.top;
            const x = e.clientX - rect.left;
            const centerY = cubeSize / 2;
            const centerX = cubeSize / 2;
            
            if (y < centerY - 10) setHoveredFace('xy');
            else if (y > centerY + 10) setHoveredFace('xz');
            else if (x > centerX + 10) setHoveredFace('yz');
            else setHoveredFace('3d');
          }}
          onMouseLeave={() => setHoveredFace(null)}
          style={{
            cursor: 'pointer',
            display: 'block',
          }}
        />
        <div style={{ 
          marginTop: '4px',
          fontSize: '9px', 
          color: '#666',
          textAlign: 'center',
        }}>
          1-4 keys
        </div>
      </div>
    );
  };

  // Right side panel - fixed width so canvas takes remaining space
  const RightPanel = () => {
    // Paths affected by Apply: tree selection + paths containing selected canvas points
    const pathsFromPoints = new Set<string>();
    selectedPoints.forEach(key => pathsFromPoints.add(`${currentLayerIndex}-${key.split('-')[0]}`));
    if (selectedPointIndex >= 0 && currentPathIndex >= 0) pathsFromPoints.add(`${currentLayerIndex}-${currentPathIndex}`);
    const keysFromTree = selectedTreePathKeys.size > 0 ? selectedTreePathKeys
      : (selectedTreePathKey ? new Set([selectedTreePathKey]) : new Set<string>());
    const allSelKeys = new Set([...keysFromTree, ...pathsFromPoints]);
    const hasPathSel = allSelKeys.size > 0;
    const selCount = allSelKeys.size;
    return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '200px', flexShrink: 0, overflowY: 'auto' }}>
      {/* Set Intensity + Clean Orphans — always at top */}
      <div style={{ background: '#1e2230', border: '1px solid #3a3a5e', borderRadius: '4px', padding: '8px' }}>
        <div style={{ color: '#aaa', fontSize: '11px', fontWeight: 'bold', marginBottom: '6px' }}>Intensity</div>
        <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
          <input
            type="number" min="0" max="127"
            value={setIntensityInput}
            onChange={(e) => setSetIntensityInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                const v = parseInt(setIntensityInput);
                if (!isNaN(v)) handleSetIntensitySelected(Math.max(0, Math.min(127, v)));
              }
            }}
            style={{ width: '52px', padding: '4px 6px', background: '#0e1e2e', color: '#fff', border: '1px solid #4a6a8a', borderRadius: '3px', fontSize: '12px' }}
          />
          <button
            onClick={() => {
              const v = parseInt(setIntensityInput);
              if (!isNaN(v)) handleSetIntensitySelected(Math.max(0, Math.min(127, v)));
            }}
            disabled={!hasPathSel}
            style={{ flex: 1, padding: '4px 6px', background: hasPathSel ? '#2a5a7e' : '#2a2a3e', border: '1px solid ' + (hasPathSel ? '#4a8aae' : '#3a3a5e'), color: hasPathSel ? '#7cf' : '#556', borderRadius: '3px', cursor: hasPathSel ? 'pointer' : 'not-allowed', fontSize: '11px', fontWeight: 'bold' }}
            title={hasPathSel ? `Apply to ${selCount} path${selCount !== 1 ? 's' : ''}` : 'Select paths first'}
          >
            Apply{hasPathSel ? ` (${selCount})` : ''}
          </button>
        </div>
        <button
          onClick={handleCleanOrphans}
          style={{ width: '100%', marginTop: '5px', padding: '4px 6px', background: '#2e1e1e', border: '1px solid #5a3a3a', color: '#c88', borderRadius: '3px', cursor: 'pointer', fontSize: '10px' }}
          title="Remove paths with ≤1 point and fix incomplete bezier paths"
        >
          🧹 Clean Orphans
        </button>
      </div>
      <LayersPanel />
      <PathPropertiesPanel />
      <EdgeSettingsPanel />
    </div>
    );
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', overflow: 'hidden', height: '100%' }}>
      <Toolbar />
      <CircleArcSettings />
      <div style={{ display: 'flex', gap: '8px', overflow: 'hidden', flex: 1 }}>
        {/* Centering wrapper — takes all remaining horizontal space */}
        <div ref={canvasContainerRef} style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
        {/* Inner div sized to the square canvas — no wasted black area */}
        <div style={{ position: 'relative', width, height, flexShrink: 0 }}>
          <canvas
            ref={canvasRef}
            width={width}
            height={height}
            tabIndex={0}
            onMouseDown={handleMouseDown}
            onMouseMove={handleMouseMove}
            onMouseUp={handleMouseUp}
            onAuxClick={e => e.preventDefault()}
            onContextMenu={e => e.preventDefault()}
            onDoubleClick={handleDoubleClick}
            onKeyDown={handleKeyDown}
            style={{
              border: '2px solid #4a4a8e',
              borderRadius: '4px',
              display: 'block',
              cursor: currentTool === 'pen'
                ? 'crosshair'
                : currentTool === 'circle' || currentTool === 'arc' || currentTool === 'polygon'
                ? 'crosshair'
                : currentTool === 'pan' && viewMode === '3d' && isDrawing
                ? 'grabbing'
                : currentTool === 'pan' && viewMode === '3d'
                ? 'grab'
                : currentTool === 'pan'
                ? 'move'
                : currentTool === 'background'
                ? isBackgroundSelected ? 'grabbing' : 'grab'
                : isMoveMode && selectedPoints.size > 0
                ? (dragStartPositionsRef.current ? 'grabbing' : 'grab')
                : 'default',
            }}
          />
          <ViewCube />
        </div>
        </div>
        <RightPanel />
      </div>
      <div style={{ color: '#888', fontSize: '12px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span>
          {currentTool === 'pen' && viewMode !== '3d' && `Drawing on ${viewMode.toUpperCase()} plane. Click to add points. Double-click to finish path.`}
          {currentTool === 'pen' && viewMode === '3d' && 'Switch to XY/XZ/YZ view to draw. 3D view is for visualization only.'}
          {currentTool === 'select' && 'Click to select points. Drag to move.'}
          {currentTool === 'circle' && '⭕ Click center, drag to set radius. Circle will be generated with specified segments.'}
          {currentTool === 'arc' && '◔ Click center, drag to set radius. Arc from start angle to end angle.'}
          {currentTool === 'polygon' && '⬡ Click center, drag to set radius. Regular polygon with specified sides.'}
          {currentTool === 'background' && '🖼️ Drag to move the background image.'}
          {currentTool === 'pan' && viewMode === '3d' && '🔄 Drag to rotate 3D view. Scroll to zoom.'}
          {currentTool === 'pan' && viewMode !== '3d' && '✋ Drag to pan. Scroll to zoom.'}
          {backgroundImage && ' | 📷 Background image loaded - use Auto-Trace to detect edges.'}
        </span>
        <span style={{ display: 'flex', gap: '16px', fontSize: '11px' }}>
          {mouseVectrexCoords && (
            <span style={{ color: '#6af', fontWeight: 'bold' }}>
              Vectrex: X={mouseVectrexCoords.x} Y={mouseVectrexCoords.y}
            </span>
          )}
          <span>View: <strong>{viewMode.toUpperCase()}</strong></span>
          {viewMode === '3d' && (
            <span>
              Rotation: Pitch={rotation3D.pitch.toFixed(0)}° Yaw={rotation3D.yaw.toFixed(0)}°
            </span>
          )}
          <span>Zoom: {(zoom * 100).toFixed(0)}%</span>
        </span>
      </div>

      {/* DXF Import Dialog */}
      {dxfImport && (() => {
        const { bbox, referencePlane, manualScale, rawPaths } = dxfImport;
        const { minX, maxX, minY, maxY, minZ, maxZ } = bbox;
        const rangeX = maxX - minX || 1, rangeY = maxY - minY || 1, rangeZ = maxZ - minZ || 1;

        let scale: number;
        if (referencePlane === 'xy') scale = 254 / Math.max(rangeX, rangeY);
        else if (referencePlane === 'xz') scale = 254 / Math.max(rangeX, rangeZ);
        else if (referencePlane === 'yz') scale = 254 / Math.max(rangeY, rangeZ);
        else scale = manualScale;

        const fmt = (v: number) => (v * scale).toFixed(1);

        // Build SVG preview path string (single <path> for performance)
        const buildPreviewPath = (): string => {
          if (rawPaths.length === 0) return '';
          const project = (pt: { x: number; y: number; z?: number }): [number, number] => {
            const z = (pt as { z?: number }).z ?? 0;
            if (referencePlane === 'xz') return [pt.x * scale, z * scale];
            if (referencePlane === 'yz') return [pt.y * scale, z * scale];
            return [pt.x * scale, pt.y * scale];
          };
          // Compute projected bounds for auto-fit
          let pMinX = Infinity, pMaxX = -Infinity, pMinY = Infinity, pMaxY = -Infinity;
          const MAX_PATHS = 3000;
          const slicedPaths = rawPaths.length > MAX_PATHS ? rawPaths.slice(0, MAX_PATHS) : rawPaths;
          for (const rp of slicedPaths)
            for (const pt of rp.pts) {
              const [px, py] = project(pt);
              if (px < pMinX) pMinX = px; if (px > pMaxX) pMaxX = px;
              if (py < pMinY) pMinY = py; if (py > pMaxY) pMaxY = py;
            }
          const pRangeX = pMaxX - pMinX || 1, pRangeY = pMaxY - pMinY || 1;
          const pCX = (pMinX + pMaxX) / 2, pCY = (pMinY + pMaxY) / 2;
          const PREV = 220, PAD = 12;
          const fit = (PREV / 2 - PAD) / Math.max(pRangeX, pRangeY) * 2;
          const tx = (px: number) => ((px - pCX) * fit + PREV / 2);
          const ty = (py: number) => (-(py - pCY) * fit + PREV / 2);
          let d = '';
          for (const rp of slicedPaths) {
            if (rp.pts.length < 2) continue;
            const [px0, py0] = project(rp.pts[0]);
            d += `M${tx(px0).toFixed(1)},${ty(py0).toFixed(1)}`;
            for (let i = 1; i < rp.pts.length; i++) {
              const [pxi, pyi] = project(rp.pts[i]);
              d += `L${tx(pxi).toFixed(1)},${ty(pyi).toFixed(1)}`;
            }
            if (rp.closed) d += 'Z';
          }
          return d;
        };
        const previewD = buildPreviewPath();
        const PREV = 220;
        const planeLabel = referencePlane === 'xz' ? 'XZ' : referencePlane === 'yz' ? 'YZ' : 'XY';

        return (
          <div style={{
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', zIndex: 2000,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{
              background: '#1e1e3a', border: '2px solid #4a4a8e', borderRadius: '8px',
              padding: '24px', minWidth: '380px', maxWidth: '520px', color: 'white', fontFamily: 'monospace',
              boxShadow: '0 8px 32px rgba(0,0,0,0.7)',
            }}>
              <h3 style={{ margin: '0 0 16px', color: '#aaaaff' }}>{dxfImport.source === 'OBJ' ? '📦' : '📐'} Import {dxfImport.source}</h3>

              {/* Bounding box info */}
              <div style={{ background: '#2a2a4e', borderRadius: '4px', padding: '10px', marginBottom: '16px', fontSize: '12px' }}>
                <div style={{ marginBottom: '4px', color: '#888' }}>DXF bounding box (original units):</div>
                <div>X: {minX.toFixed(2)} → {maxX.toFixed(2)} <span style={{ color: '#aaa' }}>({rangeX.toFixed(2)})</span></div>
                <div>Y: {minY.toFixed(2)} → {maxY.toFixed(2)} <span style={{ color: '#aaa' }}>({rangeY.toFixed(2)})</span></div>
                <div>Z: {minZ.toFixed(2)} → {maxZ.toFixed(2)} <span style={{ color: '#aaa' }}>({rangeZ.toFixed(2)})</span></div>
                <div style={{ marginTop: '6px', color: '#888' }}>{rawPaths.length} {dxfImport.source === 'OBJ' ? 'edge(s)' : 'path(s)'} found</div>
              </div>

              {/* OBJ-only: edge mode toggle + angle threshold */}
              {dxfImport.source === 'OBJ' && dxfImport.objEdges && dxfImport.objVerts && (() => {
                const mode = dxfImport.edgeMode ?? 'hard';
                const vectrexBudget = rawPaths.length;
                const budgetColor = vectrexBudget <= 80 ? '#4f4' : vectrexBudget <= 200 ? '#fa4' : '#f44';

                const applyMode = (newMode: 'hard' | 'silhouette', deg?: number, plane?: typeof dxfImport.referencePlane) => {
                  const useDeg = deg ?? (dxfImport.angleThreshold ?? 25);
                  const usePlane = plane ?? dxfImport.referencePlane;
                  let edgeList: [number, number][];
                  if (newMode === 'silhouette') {
                    edgeList = silhouetteEdges(dxfImport.objEdges!, usePlane);
                  } else {
                    const cos = Math.cos((useDeg * Math.PI) / 180);
                    edgeList = (dxfImport.objEdges ?? []).filter(e => e.border || e.dot < cos).map(e => [e.a, e.b]);
                  }
                  const rp = edgeList.length > 0 ? chainObjEdges(edgeList, dxfImport.objVerts!) : [];
                  setDxfImport({ ...dxfImport, edgeMode: newMode, angleThreshold: useDeg, referencePlane: usePlane, rawPaths: rp });
                };

                return (
                  <div style={{ marginBottom: '16px' }}>
                    {/* Mode toggle */}
                    <div style={{ display: 'flex', gap: '6px', marginBottom: '10px' }}>
                      {(['hard', 'silhouette'] as const).map(m => (
                        <button key={m} onClick={() => applyMode(m)}
                          style={{ flex: 1, padding: '6px', borderRadius: '4px', border: '1px solid #4a4a8e', cursor: 'pointer', fontSize: '12px',
                            background: mode === m ? '#4a4a8e' : '#2a2a4e', color: 'white', fontWeight: mode === m ? 'bold' : 'normal' }}>
                          {m === 'hard' ? '📐 Hard Edges' : '🔆 Silhouette'}
                        </button>
                      ))}
                    </div>
                    {mode === 'silhouette' && (
                      <div style={{ fontSize: '11px', color: '#8af', marginBottom: '8px', background: '#1a1a30', borderRadius: '4px', padding: '6px 8px' }}>
                        Muestra solo los edges donde las normales de las caras adyacentes cruzan el plano de visión — perfecto para cilindros y esferas.
                      </div>
                    )}
                    {/* Angle slider — only for hard mode */}
                    {mode === 'hard' && (
                      <>
                        <div style={{ marginBottom: '6px', fontSize: '13px', display: 'flex', justifyContent: 'space-between' }}>
                          <span>Hard edge angle: <b>{dxfImport.angleThreshold ?? 25}°</b></span>
                        </div>
                        <input type="range" min="1" max="90" step="1"
                          value={dxfImport.angleThreshold ?? 25}
                          style={{ width: '100%', accentColor: '#4a4a8e' }}
                          onChange={(ev) => applyMode('hard', parseInt(ev.target.value))}
                        />
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '10px', color: '#666', marginTop: '2px' }}>
                          <span>1° (all)</span><span>90° (only sharp)</span>
                        </div>
                      </>
                    )}
                    {/* Path count + Vectrex budget */}
                    <div style={{ marginTop: '8px', fontSize: '11px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ color: '#888' }}>{rawPaths.length} paths</span>
                      <span style={{ color: budgetColor, fontWeight: 'bold' }}>
                        {vectrexBudget <= 80 ? '✓ Vectrex OK' : vectrexBudget <= 200 ? '⚠ Many paths' : '✗ Too many for Vectrex'}
                      </span>
                    </div>
                  </div>
                );
              })()}

              {/* OBJ-only: live SVG preview */}
              {dxfImport.source === 'OBJ' && (
                <div style={{ marginBottom: '16px' }}>
                  <div style={{ fontSize: '11px', color: '#888', marginBottom: '4px', display: 'flex', justifyContent: 'space-between' }}>
                    <span>Preview — {planeLabel} plane</span>
                    {rawPaths.length > 3000 && <span style={{ color: '#fa8' }}>⚠ showing first 3000 of {rawPaths.length} paths</span>}
                  </div>
                  <svg width={PREV} height={PREV}
                    style={{ background: '#080818', borderRadius: '4px', border: '1px solid #333', display: 'block', margin: '0 auto' }}>
                    {/* crosshair */}
                    <line x1={PREV/2} y1={0} x2={PREV/2} y2={PREV} stroke="#1a1a3a" strokeWidth="1" />
                    <line x1={0} y1={PREV/2} x2={PREV} y2={PREV/2} stroke="#1a1a3a" strokeWidth="1" />
                    {/* Vectrex ±127 border */}
                    <rect x={10} y={10} width={PREV-20} height={PREV-20} fill="none" stroke="#2a2a5a" strokeWidth="1" strokeDasharray="4,4" />
                    {previewD
                      ? <path d={previewD} fill="none" stroke="#5af" strokeWidth="0.8" />
                      : <text x={PREV/2} y={PREV/2} textAnchor="middle" fill="#555" fontSize="12">No edges</text>
                    }
                  </svg>
                </div>
              )}

              {/* Reference plane selector */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{ marginBottom: '8px', fontSize: '13px' }}>Fit to plane (scaled to ±127):</div>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                  {(['xy', 'xz', 'yz', 'manual'] as const).map((p) => (
                    <button key={p}
                      onClick={() => {
                        // In silhouette mode: recompute paths for new view direction
                        if (dxfImport.source === 'OBJ' && (dxfImport.edgeMode ?? 'hard') === 'silhouette' && dxfImport.objEdges && dxfImport.objVerts) {
                          const edgeList = silhouetteEdges(dxfImport.objEdges, p);
                          const rp = edgeList.length > 0 ? chainObjEdges(edgeList, dxfImport.objVerts) : [];
                          setDxfImport({ ...dxfImport, referencePlane: p, rawPaths: rp });
                        } else {
                          setDxfImport({ ...dxfImport, referencePlane: p });
                        }
                      }}
                      style={{
                        padding: '6px 12px', borderRadius: '4px', border: '1px solid #4a4a8e', cursor: 'pointer',
                        background: referencePlane === p ? '#4a4a8e' : '#2a2a4e', color: 'white', fontSize: '12px',
                      }}>
                      {p === 'manual' ? 'Manual scale' : p.toUpperCase()}
                    </button>
                  ))}
                </div>
              </div>

              {/* Manual scale input */}
              {referencePlane === 'manual' && (
                <div style={{ marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px' }}>
                  <label>Scale factor:</label>
                  <input type="number" min="0.0001" step="0.001"
                    value={manualScale}
                    onChange={(ev) => setDxfImport({ ...dxfImport, manualScale: parseFloat(ev.target.value) || manualScale })}
                    style={{ width: '100px', background: '#2a2a4e', border: '1px solid #4a4a8e', color: 'white', padding: '4px 8px', borderRadius: '4px' }}
                  />
                  <span style={{ color: '#888' }}>Vectrex units / DXF unit</span>
                </div>
              )}

              {/* Result preview */}
              <div style={{ background: '#2a2a4e', borderRadius: '4px', padding: '10px', marginBottom: '20px', fontSize: '12px' }}>
                <div style={{ marginBottom: '4px', color: '#888' }}>Result size in Vectrex units (scale = {scale.toFixed(4)}):</div>
                <div style={{ color: Math.abs(parseFloat(fmt(rangeX))) > 254 ? '#ff6666' : '#6f6' }}>X: ±{(parseFloat(fmt(rangeX)) / 2).toFixed(1)}</div>
                <div style={{ color: Math.abs(parseFloat(fmt(rangeY))) > 254 ? '#ff6666' : '#6f6' }}>Y: ±{(parseFloat(fmt(rangeY)) / 2).toFixed(1)}</div>
                <div style={{ color: Math.abs(parseFloat(fmt(rangeZ))) > 254 ? '#ff6666' : '#6af' }}>Z: ±{(parseFloat(fmt(rangeZ)) / 2).toFixed(1)}</div>
                {(parseFloat(fmt(rangeX)) > 254 || parseFloat(fmt(rangeY)) > 254) && (
                  <div style={{ color: '#ff9966', marginTop: '4px' }}>⚠ Values exceeding ±127 will be clamped</div>
                )}
              </div>

              {/* Actions */}
              <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                <button onClick={() => setDxfImport(null)}
                  style={{ padding: '8px 16px', background: '#3a3a5e', border: 'none', borderRadius: '4px', color: 'white', cursor: 'pointer' }}>
                  Cancel
                </button>
                <button onClick={confirmDxfImport}
                  style={{ padding: '8px 16px', background: '#3a6a8e', border: 'none', borderRadius: '4px', color: 'white', cursor: 'pointer', fontWeight: 'bold' }}>
                  Import
                </button>
              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
};

export default VectorEditor;
