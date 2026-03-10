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

// Types from the .vec format
interface Point {
  x: number;
  y: number;
  z?: number; // Optional Z coordinate for 3D vectors
}

interface VecPath {
  name: string;
  intensity: number;
  closed: boolean;
  points: Point[];
}

interface Layer {
  name: string;
  visible: boolean;
  paths: VecPath[];
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

type Tool = 'select' | 'pen' | 'line' | 'polygon' | 'circle' | 'arc' | 'pan' | 'background';
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
  const mousePenPosRef = useRef<{ x: number; y: number } | null>(null);
  const circlePreviewRef = useRef<{ center: { x: number; y: number }; radius: number; tool: string } | null>(null);

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
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [viewMode, setViewMode] = useState<ViewMode>('xy');
  const [rotation3D, setRotation3D] = useState({ pitch: 30, yaw: 45 }); // degrees
  const [isDrawing, setIsDrawing] = useState(false);
  const [tempPoints, setTempPoints] = useState<Point[]>([]);
  
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
    console.log('[VectorEditor] handleScale called with factor:', factor);
    console.log('[VectorEditor] Current resource:', JSON.stringify(resource, null, 2));
    
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
    
    console.log('[VectorEditor] Scaled', pointsScaled, 'points with factor', factor);
    console.log('[VectorEditor] Scaled resource:', JSON.stringify(scaled, null, 2));
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
  const project3DTo2D = useCallback((point: Point): { x: number; y: number } => {
    const x = point.x || 0;
    const y = point.y || 0;
    const z = point.z || 0;
    
    if (viewMode === 'xy') {
      return { x, y };
    } else if (viewMode === 'xz') {
      return { x, y: z };
    } else if (viewMode === 'yz') {
      return { x: y, y: z };
    } else { // 3D perspective
      const pitch = (rotation3D.pitch * Math.PI) / 180;
      const yaw = (rotation3D.yaw * Math.PI) / 180;
      
      // Rotate around Y axis (yaw)
      const x1 = x * Math.cos(yaw) - z * Math.sin(yaw);
      const z1 = x * Math.sin(yaw) + z * Math.cos(yaw);
      
      // Rotate around X axis (pitch)
      const y2 = y * Math.cos(pitch) - z1 * Math.sin(pitch);
      const z2 = y * Math.sin(pitch) + z1 * Math.cos(pitch);
      
      // Simple orthographic projection (ignore z2 for depth)
      return { x: x1, y: y2 };
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
      
      // Stretch image to fill 100% of the canvas area, centered so zoom scales from center
      const drawWidth = width * zoom;
      const drawHeight = height * zoom;
      const drawX = (width - drawWidth) / 2 + pan.x + backgroundOffset.x;
      const drawY = (height - drawHeight) / 2 + pan.y + backgroundOffset.y;
      
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
      
      // Screen boundaries: X: -127 to 126, Y: -120 to 120
      const screenLeft = resourceToCanvas({ x: -127, y: 0 });
      const screenRight = resourceToCanvas({ x: 126, y: 0 });
      const screenTop = resourceToCanvas({ x: 0, y: 120 });
      const screenBottom = resourceToCanvas({ x: 0, y: -120 });
      
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

        if (layerIdx === currentLayerIndex && pathIdx === currentPathIndex) {
          ctx.fillStyle = '#ffff00';
          for (let i = 0; i < path.points.length; i++) {
            const pt = path.points[i];
            if (!pt) continue;
            const ptCanvas = resourceToCanvas(pt);
            const isSelected = selectedPoints.has(`${pathIdx}-${i}`);
            ctx.beginPath();
            ctx.arc(ptCanvas.x, ptCanvas.y, i === selectedPointIndex || isSelected ? 6 : 4, 0, Math.PI * 2);
            ctx.fill();
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
  }, [resource, currentLayerIndex, currentPathIndex, selectedPointIndex, selectedPoints, tempPoints, pan, zoom, width, height, resourceToCanvas, backgroundImage, backgroundOpacity, showBackground, isBoxSelecting, boxStart, boxEnd, showPreview, previewPaths, showEdgeSettings, isBackgroundSelected, backgroundOffset, isSubtractSelect, isMoveMode]);

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
  
  // Restore background image from resource on load
  useEffect(() => {
    if (resource.backgroundImage && !backgroundImage) {
      const img = new Image();
      img.onload = () => {
        setBackgroundImage(img);
        setShowBackground(true);
      };
      img.src = resource.backgroundImage;
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
      if (currentTool === 'pen' && tempPoints.length >= 2) {
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
    
    const point = canvasToResource(canvasX, canvasY);

    if (currentTool === 'pen') {
      setTempPoints([...tempPoints, point]);
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
      for (let pathIdx = 0; pathIdx < layer.paths.length; pathIdx++) {
        const path = layer.paths[pathIdx];
        if (!path || !Array.isArray(path.points)) continue;
        for (let pointIdx = 0; pointIdx < path.points.length; pointIdx++) {
          const ptRaw = path.points[pointIdx];
          if (!ptRaw) continue;
          const pt = resourceToCanvas(ptRaw);
          const dist = Math.sqrt((pt.x - canvasX) ** 2 + (pt.y - canvasY) ** 2);
          if (dist < closestDist && dist < 10) {
            closestDist = dist;
            closestPath = pathIdx;
            closestPoint = pointIdx;
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
        } else {
          // Clicked on path line but not a point - just select the path
          setSelectedPointIndex(-1);
          if (!e.shiftKey) {
            setSelectedPoints(new Set());
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
    if (currentTool === 'pen' && tempPoints.length > 0) {
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
    // Clear drag state for 3D rotation
    dragStartRef.current = null;
    setIsBackgroundSelected(false);
    
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
  const handleWheel = useCallback((e: React.WheelEvent<HTMLCanvasElement>) => {
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
    const newZoom = Math.max(0.5, Math.min(4, zoom * zoomFactor));
    
    // Calculate new pan to keep world position under cursor
    const newPanX = mouseX - centerX - worldX * scale * newZoom;
    const newPanY = mouseY - centerY - worldY * scale * newZoom;
    
    setZoom(newZoom);
    setPan({ x: newPanX, y: newPanY });
  }, [zoom, pan, width, height, resource.canvas.width]);
  
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

  const handleDoubleClick = () => {
    mousePenPosRef.current = null;
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
      finalizePenPath();
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
        onClick={handleDeleteSelected}
        disabled={selectedPoints.size === 0 && selectedPointIndex < 0}
        style={{ 
          padding: '8px 12px', 
          background: (selectedPoints.size > 0 || selectedPointIndex >= 0) ? '#8a3a3e' : '#4a4a5e', 
          color: 'white', 
          border: 'none', 
          borderRadius: '4px', 
          cursor: (selectedPoints.size > 0 || selectedPointIndex >= 0) ? 'pointer' : 'not-allowed',
          opacity: (selectedPoints.size > 0 || selectedPointIndex >= 0) ? 1 : 0.5,
        }}
        title="Delete selected points (Delete key)"
      >
        🗑️ Delete {selectedPoints.size > 0 ? `(${selectedPoints.size})` : ''}
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
        onClick={() => setZoom(z => Math.min(z * 1.2, 4))}
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

        {/* All vector layers */}
        {resource.layers.map((layer, layerIdx) => {
          const isActive = layerIdx === currentLayerIndex;
          const pathCount = layer.paths.length;
          const pointCount = layer.paths.reduce((s, p) => s + p.points.length, 0);
          return (
            <div
              key={layerIdx}
              onClick={() => { setCurrentLayerIndex(layerIdx); setSelectedPoints(new Set()); setCurrentPathIndex(-1); setSelectedPointIndex(-1); }}
              style={{ padding: '6px 8px', background: isActive ? '#4a4a8e' : '#2e2e4e', color: isActive ? 'white' : '#aaa', borderRadius: '4px', marginBottom: '4px', fontSize: '12px', cursor: 'pointer', border: isActive ? '1px solid #7a7abf' : '1px solid transparent' }}
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
              </div>
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
  const RightPanel = () => (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', width: '200px', flexShrink: 0, overflowY: 'auto' }}>
      <LayersPanel />
      <PathPropertiesPanel />
      <EdgeSettingsPanel />
    </div>
  );

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
            onWheel={handleWheel}
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
    </div>
  );
};

export default VectorEditor;
