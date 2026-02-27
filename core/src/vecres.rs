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
    /// Points in the path
    pub points: Vec<Point>,
}

fn default_intensity() -> u8 { 127 }

/// A point in 2D space
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Point {
    pub x: i16,
    pub y: i16,
    /// Optional intensity override for this specific point (0-255)
    /// If present, triggers Intensity_a call before drawing to this point
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub intensity: Option<u8>,
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
        }
    }
    
    /// Get all visible paths flattened
    pub fn visible_paths(&self) -> Vec<&VecPath> {
        self.layers.iter()
            .filter(|l| l.visible)
            .flat_map(|l| l.paths.iter())
            .collect()
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
    

    // Helper: format i8 value for ASM (compatible with both native and lwasm)
    // lwasm requires hex format $XX for negative values, no spaces after commas
    fn format_byte(value: i8) -> String {
        format!("${:02X}", value as u8)
    }
    
    // Helper: format two bytes for FCB (lwasm compatibility: no space after comma)
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
        
        // Emit asset constants for runtime calculations
        asm.push_str(&format!("_{}_WIDTH EQU {}\n", symbol_name, width));
        asm.push_str(&format!("_{}_CENTER_X EQU {}\n", symbol_name, center_x));
        asm.push_str(&format!("_{}_CENTER_Y EQU {}\n", symbol_name, center_y));
        asm.push_str("\n");
        
        // Process ALL paths (multi-path support)
        if self.visible_paths().is_empty() {
            asm.push_str(&format!("_{}_VECTORS:\n", symbol_name));
            asm.push_str("    FCB 2               ; end marker (empty)\n");
            return asm;
        }
        
        // Generate individual labels for each path (_NAME_PATH0, _NAME_PATH1, ...)
        // Main label (_NAME_VECTORS) points to header with path count + path pointers
        let path_count = self.visible_paths().len();
        
        asm.push_str(&format!("_{}_VECTORS:  ; Main entry (header + {} path(s))\n", symbol_name, path_count));
        asm.push_str(&format!("    FCB {}               ; path_count (runtime metadata)\n", path_count));
        
        // Emit pointer table for all paths (allows runtime iteration)
        for path_idx in 0..path_count {
            asm.push_str(&format!("    FDB _{}_PATH{}        ; pointer to path {}\n", symbol_name, path_idx, path_idx));
        }
        asm.push_str("\n");
        
        for (path_idx, path) in self.visible_paths().iter().enumerate() {
            let is_last_path = path_idx == self.visible_paths().len() - 1;
            
            // Create label for each path (PATH0, PATH1, etc.)
            asm.push_str(&format!("_{}_PATH{}:    ; Path {}\n", symbol_name, path_idx, path_idx));
            
            if path.points.is_empty() {
                // Completely empty path - skip
                if is_last_path {
                    asm.push_str("    FCB 2                ; end marker (no points)\n");
                }
                continue;
            }
            
            let default_intensity = path.intensity;
            let p0 = &path.points[0];
            // Subtract center to emit RELATIVE coordinates
            let y0_relative = (p0.y - center_y).clamp(-127, 127) as i8;
            let x0_relative = (p0.x - center_x).clamp(-127, 127) as i8;
            
            // Malban format header: intensity, y_start, x_start, next_y, next_x
            asm.push_str(&format!("    FCB {}              ; path{}: intensity\n", default_intensity, path_idx));
            asm.push_str(&format!("    FCB {},{},0,0        ; path{}: header (y={}, x={}, relative to center)\n", 
                Self::format_byte(y0_relative), Self::format_byte(x0_relative), path_idx, y0_relative, x0_relative));
            
            // Generate lines: flag=$FF (draw), dy, dx
            // Segments longer than 127 units are split into multiple sub-segments
            for j in 0..path.points.len()-1 {
                let p_from = &path.points[j];
                let p_to = &path.points[j + 1];
                let dx = p_to.x - p_from.x;
                let dy = p_to.y - p_from.y;
                Self::emit_split_segment(&mut asm, dx, dy, &format!("line {}", j));
            }

            // If closed path, add closing line back to first point
            if path.closed && path.points.len() > 2 {
                let p_from = &path.points[path.points.len() - 1];
                let p_to = &path.points[0];
                let dx = p_to.x - p_from.x;
                let dy = p_to.y - p_from.y;
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
