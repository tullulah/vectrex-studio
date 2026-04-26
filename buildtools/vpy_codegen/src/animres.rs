//! VPy Animation Resource format (.vanim)
//!
//! Frame-by-frame vector animations that reference existing .vec assets
//! and define inline paths per-frame.  Compiled to ROM data that is
//! driven at runtime by DRAW_ANIM_RUNTIME.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

// ---------------------------------------------------------------------------
// JSON deserialization types
// ---------------------------------------------------------------------------

/// Root structure of a .vanim file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VanimResource {
    /// File format version
    #[serde(default = "default_version")]
    pub version: String,
    /// Animation name (used for symbol generation)
    pub name: String,
    /// Whether the animation loops (true) or plays once and freezes (false)
    #[serde(default = "default_loop")]
    pub r#loop: bool,
    /// Static cel layer: .vec names drawn on every frame before per-frame content.
    /// Like animation cel backgrounds — defined once, reused at 2 bytes/frame cost.
    #[serde(default)]
    pub base_refs: Vec<String>,
    /// Ordered list of frames
    pub frames: Vec<VanimFrame>,
}

fn default_version() -> String { "1.0".to_string() }
fn default_loop() -> bool { true }

/// A single animation frame
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VanimFrame {
    /// Frame index (informational, must be 0-based sequential)
    pub index: u32,
    /// How many 50 Hz game ticks to show this frame
    #[serde(default = "default_ticks")]
    pub duration_ticks: u8,
    /// Names of .vec assets to draw for this frame (shared ROM data, no duplication)
    #[serde(default)]
    pub vec_refs: Vec<String>,
    /// Inline vector paths defined only for this frame
    #[serde(default)]
    pub paths: Vec<VanimPath>,
}

fn default_ticks() -> u8 { 4 }

/// An inline vector path inside a .vanim frame
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VanimPath {
    /// Path name (informational only)
    #[serde(default)]
    pub name: String,
    /// Beam intensity (0-127)
    #[serde(default = "default_intensity")]
    pub intensity: u8,
    /// Points defining the path (first point = move-to origin)
    pub points: Vec<VanimPoint>,
}

fn default_intensity() -> u8 { 127 }

/// A 2D point
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct VanimPoint {
    pub x: i16,
    pub y: i16,
}

// ---------------------------------------------------------------------------
// Loading
// ---------------------------------------------------------------------------

impl VanimResource {
    /// Load a .vanim resource from a file
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let resource: VanimResource = serde_json::from_str(&content)?;
        Ok(resource)
    }

    /// Estimate ROM bytes for size calculations (rough)
    pub fn estimate_binary_size(&self) -> usize {
        // Header: 4 bytes (frame_count + loop + base_ref_count + frame_table_offset)
        //       + 2*base_refs + 2*frame_count FDB pointers
        let mut size = 4 + self.base_refs.len() * 2 + self.frames.len() * 2;
        for frame in &self.frames {
            // Frame header: duration_ticks(1) + vec_ref_count(1) + 2*vec_refs + inline_path_count(1)
            size += 3 + frame.vec_refs.len() * 2;
            for path in &frame.paths {
                // intensity(1) + y_start(1) + x_start(1) = 3
                // each segment: FCB $FF, dy, dx = 3 bytes; end = 1 byte
                let segments = if path.points.len() > 1 { path.points.len() - 1 } else { 0 };
                size += 3 + segments * 3 + 1;
            }
        }
        size
    }
}

// ---------------------------------------------------------------------------
// ASM code generation (m6809 target)
// ---------------------------------------------------------------------------

/// Helper: format an i8 value as $XX hex (lwasm compatible)
fn fmt_byte(v: i8) -> String {
    format!("${:02X}", v as u8)
}

/// Compile a single inline path to the Draw_Sync_List compact binary format.
/// Format identical to what compile_to_asm() emits for .vec paths:
///   FCB intensity
///   FCB y_start, x_start, 0, 0       (move-to header — 4 bytes)
///   FCB $FF, dy, dx                   (draw segments, repeated)
///   FCB 2                             (end marker)
fn compile_inline_path(path: &VanimPath) -> String {
    let mut asm = String::new();

    if path.points.is_empty() {
        asm.push_str("    FCB 2                    ; empty inline path\n");
        return asm;
    }

    let p0 = &path.points[0];
    let y0 = p0.y.clamp(-127, 127) as i8;
    let x0 = p0.x.clamp(-127, 127) as i8;

    asm.push_str(&format!("    FCB {}               ; intensity\n", path.intensity));
    asm.push_str(&format!("    FCB {},{},0,0        ; y_start={} x_start={}\n",
        fmt_byte(y0), fmt_byte(x0), y0, x0));

    // Segments: FCB $FF, dy, dx
    for i in 0..path.points.len() - 1 {
        let from = &path.points[i];
        let to = &path.points[i + 1];
        let dx = to.x - from.x;
        let dy = to.y - from.y;
        emit_split_segment(&mut asm, dx, dy);
    }

    asm.push_str("    FCB 2                    ; end of inline path\n");
    asm
}

/// Emit one or more FCB $FF,dy,dx segments, splitting if |dx| or |dy| > 127.
fn emit_split_segment(asm: &mut String, dx: i16, dy: i16) {
    let dx = dx as i32;
    let dy = dy as i32;
    let max_delta = dx.abs().max(dy.abs());
    let n = if max_delta == 0 { 1 } else { (max_delta + 126) / 127 };
    let mut rem_dx = dx;
    let mut rem_dy = dy;
    for i in 0..n {
        let steps_left = n - i;
        let sub_dx = rem_dx / steps_left;
        let sub_dy = rem_dy / steps_left;
        rem_dx -= sub_dx;
        rem_dy -= sub_dy;
        asm.push_str(&format!("    FCB $FF,{},{}     ; dy={} dx={}\n",
            fmt_byte(sub_dy as i8), fmt_byte(sub_dx as i8), sub_dy, sub_dx));
    }
}

/// Compile a .vanim file into Vectrex ASM data.
///
/// The `name_upper` is the uppercased symbol prefix (e.g. "WALK_CYCLE").
///
/// Vec-ref pointers use the `_VECNAME_VECTORS` symbol that `compile_to_asm_with_name`
/// generates in vecres.rs — the same symbol that DRAW_VECTOR_BANKED/DRAW_VECTOR uses.
pub fn compile_vanim_to_asm(resource: &VanimResource, asset_name: &str) -> String {
    let mut asm = String::new();
    let sym = asset_name.to_uppercase().replace('-', "_").replace(' ', "_");
    let frame_count = resource.frames.len();

    let base_ref_count = resource.base_refs.len();
    // frame_table_offset = 4 (fixed header bytes) + base_ref_count * 2 (FDB entries)
    let frame_table_offset = 4 + base_ref_count * 2;

    asm.push_str(&format!("; .vanim animation data: {} ({} frames, loop={}, base_refs={})\n",
        asset_name, frame_count, resource.r#loop, base_ref_count));
    asm.push_str("\n");

    // --- Header ---
    // byte 0: frame_count
    // byte 1: loop flag
    // byte 2: base_ref_count
    // byte 3: frame_table_offset (= 4 + base_ref_count*2)
    // bytes 4..: FDB ptrs to base_ref _VECNAME_VECTORS (static cel layer)
    // at frame_table_offset: FDB ptrs to per-frame data
    asm.push_str(&format!("_ANIM_{}:\n", sym));
    asm.push_str(&format!("    FCB {}               ; frame_count\n", frame_count));
    asm.push_str(&format!("    FCB {}               ; loop flag (1=loop, 0=freeze)\n",
        if resource.r#loop { 1 } else { 0 }));
    asm.push_str(&format!("    FCB {}               ; base_ref_count\n", base_ref_count));
    asm.push_str(&format!("    FCB {}               ; frame_table_offset\n", frame_table_offset));

    // Base ref FDB pointers (static cel layer — drawn before every frame)
    for base_name in &resource.base_refs {
        let vec_sym = base_name.to_uppercase().replace('-', "_").replace(' ', "_");
        asm.push_str(&format!("    FDB _{}_VECTORS      ; base_ref: {}\n", vec_sym, base_name));
    }

    // FDB pointer table for each frame
    for i in 0..frame_count {
        asm.push_str(&format!("    FDB _ANIM_{}_F{}       ; frame {} pointer\n", sym, i, i));
    }
    asm.push_str("\n");

    // --- Per-frame data ---
    for (fi, frame) in resource.frames.iter().enumerate() {
        asm.push_str(&format!("_ANIM_{}_F{}:\n", sym, fi));
        asm.push_str(&format!("    FCB {}               ; duration_ticks\n", frame.duration_ticks));
        asm.push_str(&format!("    FCB {}               ; vec_ref_count\n", frame.vec_refs.len()));

        // FDB pointers to referenced .vec symbols
        for vec_name in &frame.vec_refs {
            let vec_sym = vec_name.to_uppercase().replace('-', "_").replace(' ', "_");
            // _VECNAME_VECTORS is the symbol emitted by vecres.rs compile_to_asm_with_name
            asm.push_str(&format!("    FDB _{}_VECTORS      ; vec_ref: {}\n", vec_sym, vec_name));
        }

        asm.push_str(&format!("    FCB {}               ; inline_path_count\n", frame.paths.len()));

        // Inline path binary data
        for path in &frame.paths {
            if !path.name.is_empty() {
                asm.push_str(&format!("    ; inline path: {}\n", path.name));
            }
            asm.push_str(&compile_inline_path(path));
        }
        asm.push_str("\n");
    }

    asm
}
