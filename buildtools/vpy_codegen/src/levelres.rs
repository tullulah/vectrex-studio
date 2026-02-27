//! VPy Level Resource format (.vplay)
//!
//! Level data resources stored as JSON that can be compiled
//! into efficient ASM/binary data for Vectrex.

use std::path::Path;
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Level resource file extension
pub const VPLAY_EXTENSION: &str = "vplay";

/// Root structure of a .vplay file (v2.0)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayLevel {
    /// File format version ("2.0")
    pub version: String,
    /// Level type identifier
    #[serde(rename = "type")]
    pub level_type: String,
    /// Level metadata
    pub metadata: VPlayMetadata,
    /// World bounds
    #[serde(rename = "worldBounds")]
    pub world_bounds: VPlayWorldBounds,
    /// Objects organized by layers
    pub layers: VPlayLayers,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayMetadata {
    pub name: String,
    #[serde(default)]
    pub author: String,
    #[serde(default)]
    pub difficulty: String,
    #[serde(default, rename = "timeLimit")]
    pub time_limit: u32,
    #[serde(default, rename = "targetScore")]
    pub target_score: u32,
    #[serde(default)]
    pub description: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayWorldBounds {
    #[serde(rename = "xMin")]
    pub x_min: i16,
    #[serde(rename = "xMax")]
    pub x_max: i16,
    #[serde(rename = "yMin")]
    pub y_min: i16,
    #[serde(rename = "yMax")]
    pub y_max: i16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayLayers {
    #[serde(default)]
    pub background: Vec<VPlayObject>,
    #[serde(default)]
    pub gameplay: Vec<VPlayObject>,
    #[serde(default)]
    pub foreground: Vec<VPlayObject>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayObject {
    pub id: String,
    #[serde(rename = "type")]
    pub obj_type: String,
    #[serde(rename = "vectorName")]
    pub vector_name: String,
    pub x: i16,
    pub y: i16,
    pub scale: f32,
    pub rotation: i16,
    #[serde(default)]
    pub intensity: Option<u8>,
    #[serde(default)]
    pub layer: String,
    #[serde(default)]
    pub visible: bool,
    #[serde(default)]
    pub velocity: Vec2,
    #[serde(default)]
    pub physics: Option<VPlayPhysics>,
    #[serde(default)]
    pub collision: Option<VPlayCollision>,
    #[serde(default)]
    pub properties: Option<serde_json::Value>,
    #[serde(default, rename = "spawnDelay")]
    pub spawn_delay: u16,
    #[serde(default, rename = "destroyOffscreen")]
    pub destroy_offscreen: bool,
    
    // Playground format compatibility (flat structure)
    #[serde(default, rename = "physicsEnabled")]
    pub physics_enabled: bool,
    #[serde(default, rename = "physicsType")]
    pub physics_type: Option<String>,
    #[serde(default)]
    pub collidable: bool,
    #[serde(default)]
    pub gravity: f32,
    #[serde(default, rename = "bounceDamping")]
    pub bounce_damping: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

impl Default for Vec2 {
    fn default() -> Self {
        Self { x: 0.0, y: 0.0 }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayPhysics {
    #[serde(rename = "type")]
    pub physics_type: String,
    #[serde(default)]
    pub gravity: f32,
    #[serde(default)]
    pub friction: f32,
    #[serde(default, rename = "bounceDamping")]
    pub bounce_damping: f32,
    #[serde(default, rename = "maxSpeed")]
    pub max_speed: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VPlayCollision {
    pub enabled: bool,
    #[serde(default)]
    pub layer: Option<String>,
    #[serde(default)]
    pub radius: Option<u16>,
    #[serde(default)]
    pub width: Option<u16>,
    #[serde(default)]
    pub height: Option<u16>,
    #[serde(default)]
    pub shape: Option<String>,
    #[serde(default, rename = "bounceWalls")]
    pub bounce_walls: bool,
    #[serde(default, rename = "destroyOnCollision")]
    pub destroy_on_collision: bool,
}

impl VPlayLevel {
    /// Load a .vplay file from disk
    pub fn load(path: &Path) -> Result<Self> {
        let content = std::fs::read_to_string(path)?;
        let level: VPlayLevel = serde_json::from_str(&content)?;
        
        // Validate version
        if level.version != "2.0" {
            anyhow::bail!("Unsupported .vplay version: {}. Expected 2.0", level.version);
        }
        
        Ok(level)
    }

    /// Compile level data to M6809 assembly
    pub fn compile_to_asm(&self) -> String {
        let mut out = String::new();
        let name = self.metadata.name.to_uppercase().replace('-', "_").replace(' ', "_");

        out.push_str(&format!("; ==== Level: {} ====\n", name));
        out.push_str(&format!("; Author: {}\n", self.metadata.author));
        out.push_str(&format!("; Difficulty: {}\n", self.metadata.difficulty));
        out.push_str("\n");

        // Level header
        out.push_str(&format!("_{}_LEVEL:\n", name));
        out.push_str(&format!("    FDB {}  ; World bounds: xMin (16-bit signed)\n", self.world_bounds.x_min));
        out.push_str(&format!("    FDB {}  ; xMax (16-bit signed)\n", self.world_bounds.x_max));
        out.push_str(&format!("    FDB {}  ; yMin (16-bit signed)\n", self.world_bounds.y_min));
        out.push_str(&format!("    FDB {}  ; yMax (16-bit signed)\n", self.world_bounds.y_max));
        out.push_str(&format!("    FDB {}  ; Time limit (seconds)\n", self.metadata.time_limit));
        out.push_str(&format!("    FDB {}  ; Target score\n", self.metadata.target_score));

        // Count objects in each layer
        let bg_count = self.layers.background.len();
        let gameplay_count = self.layers.gameplay.len();
        let fg_count = self.layers.foreground.len();

        out.push_str(&format!("    FCB {}  ; Background object count\n", bg_count));
        out.push_str(&format!("    FCB {}  ; Gameplay object count\n", gameplay_count));
        out.push_str(&format!("    FCB {}  ; Foreground object count\n", fg_count));

        // Pointers to layer data
        out.push_str(&format!("    FDB _{}_BG_OBJECTS\n", name));
        out.push_str(&format!("    FDB _{}_GAMEPLAY_OBJECTS\n", name));
        out.push_str(&format!("    FDB _{}_FG_OBJECTS\n", name));
        out.push_str("\n");

        // Emit background objects
        out.push_str(&format!("_{}_BG_OBJECTS:\n", name));
        for obj in &self.layers.background {
            out.push_str(&self.compile_object(obj));
        }
        out.push_str("\n");

        // Emit gameplay objects
        out.push_str(&format!("_{}_GAMEPLAY_OBJECTS:\n", name));
        for obj in &self.layers.gameplay {
            out.push_str(&self.compile_object(obj));
        }
        out.push_str("\n");

        // Emit foreground objects
        out.push_str(&format!("_{}_FG_OBJECTS:\n", name));
        for obj in &self.layers.foreground {
            out.push_str(&self.compile_object(obj));
        }
        out.push_str("\n");

        out
    }

    /// Compile a single object to assembly
    fn compile_object(&self, obj: &VPlayObject) -> String {
        let mut out = String::new();
        
        out.push_str(&format!("; Object: {} ({})\n", obj.id, obj.obj_type));
        
        // Object type as byte (enum mapping)
        let type_byte = match obj.obj_type.as_str() {
            "player_start" => 0,
            "enemy" => 1,
            "obstacle" => 2,
            "collectible" => 3,
            "background" => 4,
            "trigger" => 5,
            _ => 255, // Unknown
        };
        out.push_str(&format!("    FCB {}  ; type\n", type_byte));
        
        // Position (signed 16-bit)
        out.push_str(&format!("    FDB {}  ; x\n", obj.x));
        out.push_str(&format!("    FDB {}  ; y\n", obj.y));
        
        // Scale (convert f32 to fixed-point 8.8: scale * 256)
        let scale_fixed = (obj.scale * 256.0) as u16;
        out.push_str(&format!("    FDB {}  ; scale (8.8 fixed)\n", scale_fixed));
        
        // Rotation (degrees as signed byte)
        out.push_str(&format!("    FCB {}  ; rotation\n", (obj.rotation % 360) as u8));
        
        // Intensity (0 = use vector's intensity, >0 = override)
        let intensity_value = obj.intensity.unwrap_or(0);
        out.push_str(&format!("    FCB {}  ; intensity (0=use vec, >0=override)\n", intensity_value));
        
        // Velocity (convert f32 to signed 8-bit)
        let vel_x = obj.velocity.x.clamp(-127.0, 127.0) as i8;
        let vel_y = obj.velocity.y.clamp(-127.0, 127.0) as i8;
        out.push_str(&format!("    FCB {}  ; velocity_x\n", vel_x as u8));
        out.push_str(&format!("    FCB {}  ; velocity_y\n", vel_y as u8));
        
        // Physics flags byte
        let mut physics_flags = 0u8;
        
        // Check nested physics structure first, then flat Playground format
        if let Some(ref physics) = obj.physics {
            if physics.physics_type == "dynamic" {
                physics_flags |= 0x01; // Bit 0: dynamic physics enabled
            }
            if physics.gravity != 0.0 {
                physics_flags |= 0x02; // Bit 1: gravity enabled
            }
        }
        
        // CRITICAL: Check flat Playground format ALWAYS (even if nested physics exists)
        // This allows collision field to coexist with physicsEnabled/physicsType
        if obj.physics_enabled {
            // Playground flat format
            if let Some(ref physics_type) = obj.physics_type {
                // All physicsType options enable physics (bit 0)
                physics_flags |= 0x01; // Bit 0: physics enabled
                
                // Check if gravity is enabled via physicsType or gravity field
                if physics_type == "gravity" || physics_type == "projectile" || obj.gravity != 0.0 {
                    physics_flags |= 0x02; // Bit 1: gravity enabled
                }
            }
        }
        out.push_str(&format!("    FCB {}  ; physics_flags\n", physics_flags));
        
        // Collision flags byte
        let mut collision_flags = 0u8;
        
        // Check nested collision structure first
        if let Some(ref collision) = obj.collision {
            if collision.enabled {
                collision_flags |= 0x01; // Bit 0: collision enabled
            }
            if collision.bounce_walls {
                collision_flags |= 0x02; // Bit 1: bounce on Y walls (top/bottom)
            }
            if let Some(ref shape) = collision.shape {
                if shape == "circle" {
                    collision_flags |= 0x04; // Bit 2: circle shape (0=rect)
                }
            }
        }
        
        // CRITICAL: Also check flat Playground format (can coexist with nested collision)
        // NOTE: collidable=true applies even when physics_enabled=false (static collision walls/platforms)
        if obj.collidable {
            collision_flags |= 0x01; // Bit 0: collision enabled
        }
        if obj.physics_enabled {
            // Check physicsType for bounce behavior
            if let Some(ref physics_type) = obj.physics_type {
                if physics_type == "bounce" || physics_type == "gravity" || physics_type == "projectile" {
                    collision_flags |= 0x02; // Bit 1: bounce on Y walls (top/bottom)
                }
            }
        }
        out.push_str(&format!("    FCB {}  ; collision_flags\n", collision_flags));
        
        // Collision radius/size (use radius for circle, width for rect)
        let collision_size = if let Some(ref collision) = obj.collision {
            collision.radius.unwrap_or(collision.width.unwrap_or(10))
        } else {
            10
        };
        out.push_str(&format!("    FCB {}  ; collision_size\n", collision_size));
        
        // Spawn delay (16-bit)
        out.push_str(&format!("    FDB {}  ; spawn_delay\n", obj.spawn_delay));
        
        // Pointer to vector data (will be resolved by linker)
        let vector_label = format!("_{}_VECTORS", obj.vector_name.to_uppercase());
        out.push_str(&format!("    FDB {}  ; vector_ptr\n", vector_label));
        
        // Properties pointer (for now, null - future: custom data)
        out.push_str("    FDB 0  ; properties_ptr (reserved)\n");
        
        out.push_str("\n");
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_vplay() {
        // This test would need an actual .vplay file
        // For now, just test struct creation
        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "test_level".to_string(),
                author: "Test Author".to_string(),
                difficulty: "medium".to_string(),
                time_limit: 120,
                target_score: 1000,
                description: "Test description".to_string(),
            },
            world_bounds: VPlayWorldBounds {
                x_min: -96,
                x_max: 95,
                y_min: -128,
                y_max: 127,
            },
            layers: VPlayLayers {
                background: vec![],
                gameplay: vec![],
                foreground: vec![],
            },
        };

        assert_eq!(level.version, "2.0");
        assert_eq!(level.metadata.name, "test_level");
    }

    #[test]
    fn test_compile_empty_level() {
        let level = VPlayLevel {
            version: "2.0".to_string(),
            level_type: "level".to_string(),
            metadata: VPlayMetadata {
                name: "empty".to_string(),
                author: "".to_string(),
                difficulty: "easy".to_string(),
                time_limit: 0,
                target_score: 0,
                description: "".to_string(),
            },
            world_bounds: VPlayWorldBounds {
                x_min: -96,
                x_max: 95,
                y_min: -128,
                y_max: 127,
            },
            layers: VPlayLayers {
                background: vec![],
                gameplay: vec![],
                foreground: vec![],
            },
        };

        let asm = level.compile_to_asm();
        assert!(asm.contains("_EMPTY_LEVEL:"));
        assert!(asm.contains("; Background object count"));
    }
}
