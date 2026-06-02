/// Automatic .vplay analysis for dynamic buffer sizing
/// 
/// This module scans all .vplay files in the project to determine:
/// 1. Maximum number of gameplay objects with physics
/// 2. Whether any physics-enabled objects exist at all
/// 
/// Benefits:
/// - No manual MAX_OBJECTS configuration needed
/// - Buffer only created if physics objects exist
/// - Optimal RAM usage per project

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use crate::codegen::BufferRequirements; // Use type from codegen to avoid circular dependency

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayMetadata {
    pub version: String,
    #[serde(rename = "type")]
    pub level_type: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayObject {
    pub id: String,
    #[serde(rename = "type")]
    pub obj_type: String,
    #[serde(rename = "vectorName")]
    pub vector_name: String,
    pub layer: String,
    pub x: i32,
    pub y: i32,
    pub rotation: Option<i32>,
    pub scale: Option<f32>,
    pub velocity: Option<VPlayVelocity>,
    #[serde(rename = "physicsEnabled")]
    pub physics_enabled: Option<bool>,
    pub collidable: Option<bool>,
    pub gravity: Option<i32>,
    #[serde(rename = "bounceDamping")]
    pub bounce_damping: Option<f32>,
    #[serde(rename = "physicsType")]
    pub physics_type: Option<String>,
    pub collision: Option<VPlayCollision>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayVelocity {
    pub x: i32,
    pub y: i32,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayCollision {
    pub enabled: bool,
    pub radius: i32,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayLayers {
    pub background: Option<Vec<VPlayObject>>,
    pub gameplay: Option<Vec<VPlayObject>>,
    pub foreground: Option<Vec<VPlayObject>>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct VPlayLevel {
    pub version: String,
    #[serde(rename = "type")]
    pub level_type: String,
    pub layers: VPlayLayers,
}

/// Scan project for .vplay files and analyze buffer requirements
pub fn analyze_project_vplay_files(project_root: &Path) -> Result<BufferRequirements, String> {
    let assets_dir = project_root.join("assets").join("playground");
    
    let mut max_objects = 0;
    let mut any_physics = false;
    let mut analyzed_files = Vec::new();
    
    if !assets_dir.exists() {
        // No assets/playground directory = no levels = no buffer needed
        return Ok(BufferRequirements {
            max_physics_objects: 0,
            needs_buffer: false,
            analyzed_files: vec![],
        });
    }
    
    // Scan all .vplay files in assets/playground
    let entries = fs::read_dir(&assets_dir)
        .map_err(|e| format!("Failed to read assets/playground: {}", e))?;
    
    for entry in entries {
        let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
        let path = entry.path();
        
        if path.extension().and_then(|s| s.to_str()) == Some("vplay") {
            match analyze_vplay_file(&path) {
                Ok(count) => {
                    analyzed_files.push(path.clone());
                    if count > 0 {
                        any_physics = true;
                        max_objects = max_objects.max(count);
                    }
                }
                Err(e) => {
                    eprintln!("⚠ Warning: Failed to parse {}: {}", path.display(), e);
                    // Continue analyzing other files
                }
            }
        }
    }
    
    Ok(BufferRequirements {
        max_physics_objects: max_objects,
        needs_buffer: any_physics,
        analyzed_files,
    })
}

/// Analyze a single .vplay file and return count of gameplay physics objects
fn analyze_vplay_file(path: &Path) -> Result<usize, String> {
    let content = fs::read_to_string(path)
        .map_err(|e| format!("Failed to read file: {}", e))?;
    
    let level: VPlayLevel = serde_json::from_str(&content)
        .map_err(|e| format!("Failed to parse JSON: {}", e))?;
    
    let mut physics_count = 0;
    
    // Check all layers for physics-enabled objects
    if let Some(gameplay_objects) = &level.layers.gameplay {
        for obj in gameplay_objects {
            if obj.physics_enabled.unwrap_or(false) {
                physics_count += 1;
            }
        }
    }
    
    if let Some(background_objects) = &level.layers.background {
        for obj in background_objects {
            if obj.physics_enabled.unwrap_or(false) {
                physics_count += 1;
            }
        }
    }
    
    if let Some(foreground_objects) = &level.layers.foreground {
        for obj in foreground_objects {
            if obj.physics_enabled.unwrap_or(false) {
                physics_count += 1;
            }
        }
    }
    
    Ok(physics_count)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    
    #[test]
    fn test_parse_vplay() {
        let test_json = r#"{
            "version": "2.0",
            "type": "level",
            "layers": {
                "background": [
                    {
                        "id": "obj1",
                        "type": "enemy",
                        "vectorName": "bubble",
                        "layer": "background",
                        "x": 10,
                        "y": 20,
                        "physicsEnabled": true
                    },
                    {
                        "id": "obj2",
                        "type": "static",
                        "vectorName": "wall",
                        "layer": "background",
                        "x": 0,
                        "y": 0,
                        "physicsEnabled": false
                    }
                ]
            }
        }"#;
        
        let level: VPlayLevel = serde_json::from_str(test_json).unwrap();
        assert_eq!(level.version, "2.0");
        
        let bg = level.layers.background.unwrap();
        assert_eq!(bg.len(), 2);
        assert_eq!(bg[0].physics_enabled.unwrap(), true);
        assert_eq!(bg[1].physics_enabled.unwrap(), false);
    }
}
