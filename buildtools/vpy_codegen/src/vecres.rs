//! VPy Vector Resource format (.vec)
//!
//! Vector graphics resources stored as JSON that can be compiled
//! into efficient ASM/binary data for Vectrex.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Vector resource file extension
#[allow(dead_code)]
pub const VEC_EXTENSION: &str = "vec";

/// A single collision mesh segment in local .vec coordinates
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VecMeshSegment {
    pub x1: i16,
    pub y1: i16,
    pub x2: i16,
    pub y2: i16,
}

/// Top-level collision mesh stored directly in the .vec file
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct VecCollisionMesh {
    #[serde(default)]
    pub segments: Vec<VecMeshSegment>,
}

/// Root structure of a .vec file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VecResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,
    /// Resource name (used for symbol generation)
    pub name: String,
    /// Author information
    #[serde(default)]
    pub author: String,
    /// Creation date
    #[serde(default)]
    pub created: String,
    /// Canvas settings
    #[serde(default)]
    pub canvas: Canvas,
    /// Layers containing paths
    #[serde(default)]
    pub layers: Vec<Layer>,
    /// Animation definitions (optional)
    #[serde(default)]
    pub animations: Vec<Animation>,
    /// Metadata (hitbox, origin, tags)
    #[serde(default)]
    pub metadata: Metadata,
    /// Center X coordinate (calculated in design time, used as mirror axis)
    #[serde(default)]
    pub center_x: Option<i16>,
    /// Center Y coordinate (calculated in design time, used as mirror/rotation axis)
    #[serde(default)]
    pub center_y: Option<i16>,
    /// Collision mesh stored in the .vec file itself (reusable across levels).
    /// When present and a .vplay object references this vec without its own segments,
    /// the compiler uses this mesh instead of falling back to AABB.
    #[serde(default, rename = "collisionMesh")]
    pub collision_mesh: Option<VecCollisionMesh>,
    /// Walkable areas defined on the asset itself (e.g. a reusable platform
    /// vec). Coordinates are RELATIVE to the vec's origin: at level codegen
    /// time each area is translated by the placed object's (x, y) and added
    /// to the level's effective area list. Inheritance order is
    /// .vec → .vplay → .venemy (least to most specific override).
    #[serde(default, rename = "walkableAreas")]
    pub walkable_areas: Vec<VecWalkableArea>,
}

/// A walkable area defined inside a .vec asset, with coordinates relative
/// to the vec's origin. Each placed instance of the vec contributes its
/// translated copy to the level's walkable_areas pool.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VecWalkableArea {
    /// Y offset from vec origin (positive = up, matches vec convention).
    pub y: i16,
    pub x_min: i16,
    pub x_max: i16,
}

fn default_version() -> String {
    "1.0".to_string()
}

/// Canvas settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Canvas {
    /// Canvas width (default 256)
    #[serde(default = "default_canvas_size")]
    pub width: u16,
    /// Canvas height (default 256)
    #[serde(default = "default_canvas_size")]
    pub height: u16,
    /// Origin position: "center", "top-left", "bottom-left"
    #[serde(default = "default_origin")]
    pub origin: String,
}

fn default_canvas_size() -> u16 { 256 }
fn default_origin() -> String { "center".to_string() }

impl Default for Canvas {
    fn default() -> Self {
        Self {
            width: 256,
            height: 256,
            origin: "center".to_string(),
        }
    }
}

/// A layer containing multiple paths
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Layer {
    /// Layer name
    pub name: String,
    /// Whether layer is visible
    #[serde(default = "default_true")]
    pub visible: bool,
    /// Paths in this layer
    #[serde(default)]
    pub paths: Vec<VecPath>,
}

fn default_true() -> bool { true }

/// A vector path (series of connected points)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VecPath {
    /// Path name
    #[serde(default)]
    pub name: String,
    /// Beam intensity (0-127)
    #[serde(default = "default_intensity")]
    pub intensity: u8,
    /// Whether path is closed (connects back to start)
    #[serde(default)]
    pub closed: bool,
    /// Path type: "polyline" (default) or "bezier"
    #[serde(default, skip_serializing_if = "Option::is_none", rename = "type")]
    pub path_type: Option<String>,
    /// Points in the path
    pub points: Vec<Point>,
}

fn default_intensity() -> u8 { 127 }

/// Bezier point role within a path
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PointType {
    #[serde(rename = "a")]
    Anchor,
    #[serde(rename = "c")]
    Control,
}

/// A point in 2D/3D space
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Point {
    pub x: i16,
    pub y: i16,
    /// Optional Z coordinate for 3D vector assets (-127 to 127)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub z: Option<i16>,
    /// Optional intensity override for this specific point (0-255)
    /// If present, triggers Intensity_a call before drawing to this point
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub intensity: Option<u8>,
    /// Bezier point role: Anchor or Control
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub t: Option<PointType>,
}

/// Animation definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Animation {
    /// Animation name
    pub name: String,
    /// Frames in the animation
    pub frames: Vec<AnimFrame>,
}

/// A single animation frame
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnimFrame {
    /// Layer to show for this frame
    pub layer: String,
    /// Frame duration in milliseconds
    #[serde(default = "default_duration")]
    pub duration: u16,
}

fn default_duration() -> u16 { 100 }

/// Resource metadata
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Metadata {
    /// Hitbox rectangle
    #[serde(default)]
    pub hitbox: Option<Rect>,
    /// Origin/pivot point
    #[serde(default)]
    pub origin: Option<Point>,
    /// Tags for categorization
    #[serde(default)]
    pub tags: Vec<String>,
}

/// A rectangle
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Rect {
    pub x: i16,
    pub y: i16,
    pub w: u16,
    pub h: u16,
}

impl VecResource {
    /// Load a .vec resource from a file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: VecResource = serde_json::from_str(&content)?;
        Ok(resource)
    }
    
    /// Save the resource to a file
    pub fn save(&self, path: &Path) -> Result<()> {
        let content = serde_json::to_string_pretty(self)?;
        std::fs::write(path, content)?;
        Ok(())
    }
    
    /// Create a new empty resource
    pub fn new(name: &str) -> Self {
        Self {
            version: "1.0".to_string(),
            name: name.to_string(),
            author: String::new(),
            created: String::new(),
            canvas: Canvas::default(),
            layers: vec![Layer {
                name: "default".to_string(),
                visible: true,
                paths: Vec::new(),
            }],
            animations: Vec::new(),
            metadata: Metadata::default(),
            center_x: None,
            center_y: None,
            collision_mesh: None,
            walkable_areas: Vec::new(),
        }
    }
    
    /// Get all visible paths flattened
    pub fn visible_paths(&self) -> Vec<&VecPath> {
        self.layers.iter()
            .filter(|l| l.visible)
            .flat_map(|l| l.paths.iter())
            .collect()
    }

    /// Get visible paths reordered to minimize beam-off travel distance.
    ///
    /// Uses greedy nearest-neighbor: starting from screen center (0,0), always
    /// pick the closest unvisited path (considering both forward and reversed
    /// traversal). This typically reduces dark travel by 35-70%.
    ///
    /// Returns owned VecPath values because reversed paths need new allocations.
    pub fn optimized_paths(&self) -> Vec<VecPath> {
        let mut remaining: Vec<VecPath> = self.visible_paths()
            .into_iter()
            .cloned()
            .collect();

        if remaining.len() <= 1 {
            return remaining;
        }

        let dist = |a: (i32, i32), b: (i32, i32)| -> i64 {
            let dx = (b.0 - a.0) as i64;
            let dy = (b.1 - a.1) as i64;
            dx * dx + dy * dy  // squared distance (no sqrt needed for comparison)
        };

        let path_start = |p: &VecPath| -> (i32, i32) {
            p.points.first().map(|pt| (pt.x as i32, pt.y as i32)).unwrap_or((0, 0))
        };
        let path_end = |p: &VecPath| -> (i32, i32) {
            p.points.last().map(|pt| (pt.x as i32, pt.y as i32)).unwrap_or((0, 0))
        };

        let mut ordered = Vec::with_capacity(remaining.len());
        let mut cur = (0i32, 0i32);  // beam starts at screen center

        while !remaining.is_empty() {
            let mut best_i = 0;
            let mut best_rev = false;
            let mut best_d = i64::MAX;

            for (i, p) in remaining.iter().enumerate() {
                let df = dist(cur, path_start(p));
                let dr = dist(cur, path_end(p));
                let (d, rev) = if df <= dr { (df, false) } else { (dr, true) };
                if d < best_d {
                    best_d = d;
                    best_i = i;
                    best_rev = rev;
                }
            }

            let mut path = remaining.remove(best_i);
            if best_rev {
                path.points.reverse();
            }
            cur = path_end(&path);
            ordered.push(path);
        }

        ordered
    }
    
    /// Get total point count
    pub fn point_count(&self) -> usize {
        self.layers.iter()
            .flat_map(|l| l.paths.iter())
            .map(|p| p.points.len())
            .sum()
    }
    
    /// Calculate X bounds (min_x, max_x) across all points - needed for mirror width calculation
    pub fn calculate_x_bounds(&self) -> (i16, i16) {
        let all_points: Vec<_> = self.layers.iter()
            .flat_map(|l| l.paths.iter())
            .flat_map(|p| p.points.iter())
            .collect();

        if all_points.is_empty() {
            return (0, 0);
        }

        let min_x = all_points.iter().map(|p| p.x).min().unwrap_or(0);
        let max_x = all_points.iter().map(|p| p.x).max().unwrap_or(0);

        (min_x, max_x)
    }

    /// Calculate Y bounds (min_y, max_y) across all points - needed for collision half_height
    pub fn calculate_y_bounds(&self) -> (i16, i16) {
        let all_points: Vec<_> = self.layers.iter()
            .flat_map(|l| l.paths.iter())
            .flat_map(|p| p.points.iter())
            .collect();

        if all_points.is_empty() {
            return (0, 0);
        }

        let min_y = all_points.iter().map(|p| p.y).min().unwrap_or(0);
        let max_y = all_points.iter().map(|p| p.y).max().unwrap_or(0);

        (min_y, max_y)
    }
    
    /// Calculate center coordinates (design time)
    /// center_x = (max_x + min_x) / 2
    /// center_y = (max_y + min_y) / 2
    pub fn calculate_center(&self) -> (i16, i16) {
        let all_points: Vec<_> = self.layers.iter()
            .flat_map(|l| l.paths.iter())
            .flat_map(|p| p.points.iter())
            .collect();
        
        if all_points.is_empty() {
            return (0, 0);
        }
        
        let min_x = all_points.iter().map(|p| p.x).min().unwrap_or(0);
        let max_x = all_points.iter().map(|p| p.x).max().unwrap_or(0);
        let min_y = all_points.iter().map(|p| p.y).min().unwrap_or(0);
        let max_y = all_points.iter().map(|p| p.y).max().unwrap_or(0);
        
        let center_x = (max_x + min_x) / 2;
        let center_y = (max_y + min_y) / 2;
        
        (center_x, center_y)
    }
    

    // de Casteljau linear interpolation
    fn dc_lerp(a: i32, b: i32, i: i32, n: i32) -> i32 {
        ((n - i) * a + i * b) / n
    }

    // de Casteljau cubic evaluation at step i/n
    fn dc_cubic(p0: i32, p1: i32, p2: i32, p3: i32, i: i32, n: i32) -> i32 {
        let q0 = Self::dc_lerp(p0, p1, i, n);
        let q1 = Self::dc_lerp(p1, p2, i, n);
        let q2 = Self::dc_lerp(p2, p3, i, n);
        let r0 = Self::dc_lerp(q0, q1, i, n);
        let r1 = Self::dc_lerp(q1, q2, i, n);
        Self::dc_lerp(r0, r1, i, n)
    }

    /// Bake a bezier path (A, C, C, A, C, C, A, ...) to a polyline.
    /// Each cubic segment is subdivided into `steps` line segments.
    /// Positional convention (i%3==0 = anchor) matches VectorEditor.tsx renderBezierPath.
    pub fn bezier_bake(points: &[Point], steps: usize) -> Vec<(i16, i16)> {
        if points.len() < 4 {
            return points.iter().map(|p| (p.x, p.y)).collect();
        }
        let n = steps.max(2) as i32;
        let mut out: Vec<(i16, i16)> = vec![(points[0].x, points[0].y)];
        let mut i = 0;
        while i + 3 < points.len() {
            let (ax, ay)   = (points[i].x as i32,     points[i].y as i32);
            let (c0x, c0y) = (points[i+1].x as i32,   points[i+1].y as i32);
            let (c1x, c1y) = (points[i+2].x as i32,   points[i+2].y as i32);
            let (bx, by)   = (points[i+3].x as i32,   points[i+3].y as i32);
            for s in 1..=n {
                out.push((
                    Self::dc_cubic(ax, c0x, c1x, bx, s, n) as i16,
                    Self::dc_cubic(ay, c0y, c1y, by, s, n) as i16,
                ));
            }
            i += 3;
        }
        out
    }

    // Helper: format i8 value for ASM (compatible with both native and lwasm)
    // lwasm requires hex format $XX for negative values, no spaces after commas
    fn format_byte(value: i8) -> String {
        format!("${:02X}", value as u8)
    }
    
    // Helper: format two bytes for FCB (lwasm compatibility: no space after comma)
    #[allow(dead_code)]
    fn format_fcb2(v1: i8, v2: i8) -> String {
        format!("{},{}", Self::format_byte(v1), Self::format_byte(v2))
    }
    
    /// Compile to Vectrex-compatible ASM data using Draw_Sync_List format (Malban optimized)
    /// Format: FCB intensity, y, x, [<0=draw | 0=move | 1=next_seg], dy, dx, ..., FCB 1, [repeat], FCB 2 (end)
    pub fn compile_to_asm(&self) -> String {
        self.compile_to_asm_with_name(None)
    }
    
    pub fn compile_to_asm_with_name(&self, override_name: Option<&str>) -> String {
        let mut asm = String::new();
        let name_to_use = override_name.unwrap_or(&self.name);
        let symbol_name = name_to_use.to_uppercase().replace("-", "_").replace(" ", "_");
        
        // Calculate asset width for mirror support (max_x - min_x)
        let (min_x, max_x) = self.calculate_x_bounds();
        let width = (max_x - min_x) as i32;
        
        // Calculate center coordinates (design time axis for mirror/rotation)
        let (center_x, center_y) = self.calculate_center();
        
        asm.push_str(&format!("; Generated from {}.vec (Malban Draw_Sync_List format)\n", name_to_use));
        asm.push_str(&format!("; Total paths: {}, points: {}\n", 
            self.visible_paths().len(), self.point_count()));
        asm.push_str(&format!("; X bounds: min={}, max={}, width={}\n", min_x, max_x, width));
        asm.push_str(&format!("; Center: ({}, {})\n", center_x, center_y));
        asm.push_str("\n");
        
        // Calculate asset height for collision half_height
        let (min_y, max_y) = self.calculate_y_bounds();
        let height = (max_y - min_y) as i32;

        // Emit asset constants for runtime calculations
        asm.push_str(&format!("_{}_WIDTH EQU {}\n", symbol_name, width));
        asm.push_str(&format!("_{}_HALF_WIDTH EQU {}\n", symbol_name, width / 2));
        asm.push_str(&format!("_{}_HEIGHT EQU {}\n", symbol_name, height));
        asm.push_str(&format!("_{}_HALF_HEIGHT EQU {}\n", symbol_name, height / 2));
        asm.push_str(&format!("_{}_CENTER_X EQU {}\n", symbol_name, center_x));
        asm.push_str(&format!("_{}_CENTER_Y EQU {}\n", symbol_name, center_y));
        asm.push_str("\n");
        
        // Process ALL paths (multi-path support)
        if self.visible_paths().is_empty() {
            asm.push_str(&format!("_{}_VECTORS:\n", symbol_name));
            asm.push_str("    FCB 2               ; end marker (empty)\n");
            return asm;
        }
        
        // Reorder paths to minimise beam-off (dark) travel — greedy nearest-neighbour.
        // Filter out degenerate paths (< 2 points = 0 segments) before counting — they would
        // still emit a full v_directMove32 + v_setScale call on PiTrex with nothing drawn.
        let paths: Vec<VecPath> = self.optimized_paths()
            .into_iter()
            .filter(|p| p.points.len() >= 2)
            .collect();
        let path_count = paths.len();
        
        asm.push_str(&format!("_{}_VECTORS:  ; Main entry (header + {} path(s))\n", symbol_name, path_count));
        asm.push_str(&format!("    FDB {}               ; path_count (2 bytes, for DRAW_VECTOR_BANKED runtime)\n", path_count));
        
        // Emit pointer table for all paths (allows runtime iteration)
        for path_idx in 0..path_count {
            asm.push_str(&format!("    FDB _{}_PATH{}        ; pointer to path {}\n", symbol_name, path_idx, path_idx));
        }
        asm.push_str("\n");
        
        for (path_idx, path) in paths.iter().enumerate() {
            let is_last_path = path_idx == paths.len() - 1;
            
            // Create label for each path (PATH0, PATH1, etc.)
            asm.push_str(&format!("_{}_PATH{}:    ; Path {}\n", symbol_name, path_idx, path_idx));
            
            if path.points.is_empty() {
                // Completely empty path - skip
                if is_last_path {
                    asm.push_str("    FCB 2                ; end marker (no points)\n");
                }
                continue;
            }

            // Bezier paths are baked to a polyline at compile time (32 steps per segment)
            let baked: Vec<(i16, i16)> = if path.path_type.as_deref() == Some("bezier") {
                Self::bezier_bake(&path.points, 32)
            } else {
                path.points.iter().map(|p| (p.x, p.y)).collect()
            };

            if baked.is_empty() {
                if is_last_path {
                    asm.push_str("    FCB 2                ; end marker (no points)\n");
                }
                continue;
            }

            let default_intensity = path.intensity;
            let (x0, y0) = baked[0];
            // Path coords relative to sprite CENTER (match core compiler: y0 - center_y, x0 - center_x)
            // This is what Draw_Sync_List_At_With_Mirrors expects: offset from beam position
            let y0_relative = (y0 - center_y).clamp(-127, 127) as i8;
            let x0_relative = (x0 - center_x).clamp(-127, 127) as i8;

            // Malban format header: intensity, y_start, x_start, next_y, next_x
            asm.push_str(&format!("    FCB {}              ; path{}: intensity\n", default_intensity, path_idx));
            asm.push_str(&format!("    FCB {},{},0,0        ; path{}: header (y={}, x={})\n",
                Self::format_byte(y0_relative), Self::format_byte(x0_relative), path_idx, y0_relative, x0_relative));

            // Generate lines: flag=$FF (draw), dy, dx
            // Segments longer than 127 units are split into multiple sub-segments
            for j in 0..baked.len()-1 {
                let (fx, fy) = baked[j];
                let (tx, ty) = baked[j + 1];
                let dx = tx - fx;
                let dy = ty - fy;
                Self::emit_split_segment(&mut asm, dx, dy, &format!("line {}", j));
            }

            // If closed path, add closing line back to first point
            if path.closed && baked.len() > 2 {
                let (fx, fy) = baked[baked.len() - 1];
                let (tx, ty) = baked[0];
                let dx = tx - fx;
                let dy = ty - fy;
                Self::emit_split_segment(&mut asm, dx, dy, "closing line");
            }
            
            // End of path marker - FCB 2 terminates this individual path
            // Draw_Sync_List processes ONE path at a time, FCB 2 marks end of current path
            asm.push_str("    FCB 2                ; End marker (path complete)\n");
            if !is_last_path {
                asm.push_str("\n");  // Blank line between paths
            }
        }

        asm
    }
    
    /// Compile to vertex-indexed 3D data table for DRAW_VECTOR_3D_RUNTIME (optimized)
    ///
    /// Format:
    ///   FDB vertex_count          ; total unique vertices (2 bytes, high byte first)
    ///   FCB x,y,z × vertex_count  ; vertex table (3 bytes each), coords clamped to ±63
    ///   FDB path_count            ; number of paths (2 bytes)
    ///   per path: FCB pt_count, closed, idx0, idx1, ...
    ///     each idx is a 0-based byte index into the vertex table
    ///
    /// Vertices are deduplicated: if the same (x,y,z) appears multiple times across
    /// all paths, it is stored once and referenced by index.  Coords are clamped to
    /// ±63 so the SMUL_LUT table (val=0..63 stride=128) works correctly.
    pub fn compile_to_3d_asm_with_name(&self, override_name: Option<&str>) -> String {
        let mut asm = String::new();
        let name_to_use = override_name.unwrap_or(&self.name);
        let symbol_name = name_to_use.to_uppercase().replace("-", "_").replace(" ", "_");

        let visible = self.visible_paths();
        if visible.is_empty() {
            asm.push_str(&format!("_{}_3D_DATA:\n", symbol_name));
            asm.push_str("    FDB 0               ; 3D vertex-indexed: no vertices\n");
            asm.push_str("    FDB 0               ; no paths\n");
            return asm;
        }

        // --- Build deduplicated vertex table ---
        // Key = (x_clamped, y_clamped, z_clamped) as i8 tuple
        // Value = 0-based index in the vertex array
        let mut vertex_map: std::collections::HashMap<(i8, i8, i8), u8> =
            std::collections::HashMap::new();
        let mut vertices: Vec<(i8, i8, i8)> = Vec::new();

        // Helper closure: get-or-insert a vertex, return its index
        let mut get_vertex = |x: i8, y: i8, z: i8| -> u8 {
            let key = (x, y, z);
            if let Some(&idx) = vertex_map.get(&key) {
                idx
            } else {
                let idx = vertices.len() as u8;
                vertices.push(key);
                vertex_map.insert(key, idx);
                idx
            }
        };

        // Build path index lists while filling the vertex table
        struct PathData {
            closed: bool,
            indices: Vec<u8>,
        }
        let mut path_data: Vec<PathData> = Vec::new();

        for path in &visible {
            if path.points.is_empty() {
                continue;
            }
            let mut indices = Vec::new();
            for pt in &path.points {
                let x = pt.x.clamp(-63, 63) as i8;
                let y = pt.y.clamp(-63, 63) as i8;
                let z = pt.z.unwrap_or(0).clamp(-63, 63) as i8;
                let idx = get_vertex(x, y, z);
                indices.push(idx);
            }
            path_data.push(PathData { closed: path.closed, indices });
        }

        let total_pts: usize = path_data.iter().map(|p| p.indices.len()).sum();
        asm.push_str(&format!(
            "\n; 3D vertex-indexed data for DRAW_VECTOR_3D ({} unique verts, {} paths, {} total point refs)\n",
            vertices.len(), path_data.len(), total_pts
        ));
        asm.push_str(&format!("_{}_3D_DATA:\n", symbol_name));

        // Emit vertex count as FDB (2 bytes, big-endian; high byte always 0 for ≤127 verts)
        asm.push_str(&format!("    FDB {}               ; vertex count (unique)\n", vertices.len()));

        // Emit vertex table: 3 bytes each (x, y, z), clamped to ±63
        for (i, &(x, y, z)) in vertices.iter().enumerate() {
            asm.push_str(&format!("    FCB {},{},{}          ; vert {}: x={},y={},z={}\n",
                Self::format_byte(x), Self::format_byte(y), Self::format_byte(z),
                i, x, y, z));
        }

        // Emit path count as FDB
        asm.push_str(&format!("    FDB {}               ; path count\n", path_data.len()));

        // Emit per-path data: pt_count, closed, idx0, idx1, ...
        for (pi, pd) in path_data.iter().enumerate() {
            asm.push_str(&format!("    FCB {}               ; path {}: point count\n",
                pd.indices.len(), pi));
            asm.push_str(&format!("    FCB {}               ; path {}: closed flag\n",
                if pd.closed { 1 } else { 0 }, pi));
            for &idx in &pd.indices {
                asm.push_str(&format!("    FCB {}               ; vertex index\n", idx));
            }
        }

        asm
    }

    /// Split a long segment (|dx| or |dy| > 127) into multiple FCB $FF sub-segments.
    /// Each sub-segment stays within the ±127 Vectrex beam range.
    fn emit_split_segment(asm: &mut String, dx: i16, dy: i16, label: &str) {
        let dx = dx as i32;
        let dy = dy as i32;
        let max_delta = (dx.abs()).max(dy.abs());
        let n = if max_delta == 0 { 1 } else { (max_delta + 126) / 127 };
        let mut rem_dx = dx;
        let mut rem_dy = dy;
        for i in 0..n {
            let steps_left = n - i;
            let sub_dx = rem_dx / steps_left;
            let sub_dy = rem_dy / steps_left;
            rem_dx -= sub_dx;
            rem_dy -= sub_dy;
            let comment = if n == 1 {
                format!("flag=-1, dy={}, dx={}", sub_dy, sub_dx)
            } else {
                format!("sub-seg {}/{} of {}: dy={}, dx={}", i + 1, n, label, sub_dy, sub_dx)
            };
            asm.push_str(&format!("    FCB $FF,{},{}          ; {}\n",
                Self::format_byte(sub_dy as i8), Self::format_byte(sub_dx as i8), comment));
        }
    }

    /// Compile to binary vectorlist format
    #[allow(dead_code)]
    pub fn compile_to_binary(&self) -> Vec<u8> {
        let mut data = Vec::new();
        
        for path in self.visible_paths() {
            data.push(path.points.len() as u8);
            data.push(path.intensity);
            
            for point in &path.points {
                let x = point.x.clamp(-127, 127) as i8;
                let y = point.y.clamp(-127, 127) as i8;
                data.push(y as u8);
                data.push(x as u8);
            }
            
            data.push(if path.closed { 0x01 } else { 0x00 });
        }
        
        data
    }
    
    /// Estimate binary size in bytes (for bank distribution)
    /// This calculates the size that the ASM will compile to
    pub fn estimate_binary_size(&self) -> usize {
        let path_count = self.visible_paths().len();
        if path_count == 0 {
            return 4; // Just EQU constants + end marker
        }
        
        let mut size = 0;
        
        // Header: path_count (2 bytes FDB) + pointers (2 bytes each)
        size += 2 + path_count * 2;
        
        // EQU constants: _WIDTH, _CENTER_X, _CENTER_Y (0 bytes - just labels)
        
        for path in self.visible_paths() {
            // Path header: intensity (1) + y,x,0,0 (4) = 5 bytes
            size += 5;
            
            // Lines: 3 bytes each (flag, dy, dx)
            let line_count = if path.points.is_empty() { 0 } else { path.points.len() - 1 };
            size += line_count * 3;
            
            // Closing line if closed path (3 bytes)
            if path.closed && path.points.len() > 2 {
                size += 3;
            }
            
            // End marker: 1 byte
            size += 1;
        }
        
        size
    }
}

/// Compile a .vec file to ASM
#[allow(dead_code)]
pub fn compile_vec_to_asm(input: &Path, output: &Path) -> Result<()> {
    let resource = VecResource::load(input)?;
    let asm = resource.compile_to_asm();
    std::fs::write(output, asm)?;
    Ok(())
}

/// Compile a .vec file to binary
#[allow(dead_code)]
pub fn compile_vec_to_binary(input: &Path, output: &Path) -> Result<()> {
    let resource = VecResource::load(input)?;
    let binary = resource.compile_to_binary();
    std::fs::write(output, binary)?;
    Ok(())
}

// Tests moved to core/tests/vecres_tests.rs to keep production code clean
