//! Type tracking during unification
//!
//! Maintains a mapping of variable names to their types as modules are unified

use std::collections::HashMap;
use crate::types::VarType;
use vpy_parser::ast::{Module, Item};

/// Tracks types of variables during module unification
#[derive(Debug, Clone)]
pub struct TypeTracker {
    /// Mapping of variable names to their types
    pub var_types: HashMap<String, VarType>,
}

impl TypeTracker {
    /// Create a new type tracker
    pub fn new() -> Self {
        TypeTracker {
            var_types: HashMap::new(),
        }
    }

    /// Track a variable type
    pub fn track_var(&mut self, name: String, var_type: VarType) {
        self.var_types.insert(name, var_type);
    }

    /// Look up a variable type
    pub fn get_var_type(&self, name: &str) -> Option<VarType> {
        self.var_types.get(name).copied()
    }

    /// Extract types from a unified module
    /// Scans all Items and builds a mapping of variable names to types
    pub fn extract_types_from_module(module: &Module) -> Self {
        let mut tracker = TypeTracker::new();

        for item in &module.items {
            match item {
                Item::Const { name, type_annotation, .. } => {
                    let var_type = VarType::from_optional(type_annotation)
                        .unwrap_or_else(VarType::default_i16);
                    tracker.track_var(name.clone(), var_type);
                }
                Item::GlobalLet { name, type_annotation, .. } => {
                    let var_type = VarType::from_optional(type_annotation)
                        .unwrap_or_else(VarType::default_i16);
                    tracker.track_var(name.clone(), var_type);
                }
                _ => {}
            }
        }

        tracker
    }

    /// Check if all referenced types are valid
    pub fn validate_types(&self) -> Result<(), String> {
        for (name, var_type) in &self.var_types {
            if !VarType::is_valid_type_name(var_type.name) {
                return Err(format!(
                    "Invalid type '{}' for variable '{}'",
                    var_type.name, name
                ));
            }
        }
        Ok(())
    }

    /// Get count of tracked variables
    pub fn len(&self) -> usize {
        self.var_types.len()
    }

    /// Check if empty
    pub fn is_empty(&self) -> bool {
        self.var_types.is_empty()
    }
}

impl Default for TypeTracker {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use vpy_parser::ast::{Expr, ModuleMeta};

    #[test]
    fn test_type_tracker_creation() {
        let tracker = TypeTracker::new();
        assert!(tracker.is_empty());
        assert_eq!(tracker.len(), 0);
    }

    #[test]
    fn test_track_var() {
        let mut tracker = TypeTracker::new();
        let var_type = VarType::from_str("u8").unwrap();
        tracker.track_var("x".to_string(), var_type);

        assert_eq!(tracker.len(), 1);
        assert!(tracker.get_var_type("x").is_some());
    }

    #[test]
    fn test_extract_types_from_const() {
        let module = Module {
            items: vec![
                Item::Const {
                    name: "SPEED".to_string(),
                    type_annotation: Some("u8".to_string()),
                    value: Expr::Number(5),
                    source_line: 1,
                },
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        let tracker = TypeTracker::extract_types_from_module(&module);
        assert_eq!(tracker.len(), 1);

        let speed_type = tracker.get_var_type("SPEED").unwrap();
        assert_eq!(speed_type.name, "u8");
        assert_eq!(speed_type.size_bytes, 1);
    }

    #[test]
    fn test_extract_types_from_global_let() {
        let module = Module {
            items: vec![
                Item::GlobalLet {
                    name: "score".to_string(),
                    type_annotation: Some("u16".to_string()),
                    value: Expr::Number(0),
                    source_line: 2,
                },
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        let tracker = TypeTracker::extract_types_from_module(&module);
        assert_eq!(tracker.len(), 1);

        let score_type = tracker.get_var_type("score").unwrap();
        assert_eq!(score_type.name, "u16");
        assert_eq!(score_type.size_bytes, 2);
    }

    #[test]
    fn test_extract_types_untyped_default_to_i16() {
        let module = Module {
            items: vec![
                Item::GlobalLet {
                    name: "x".to_string(),
                    type_annotation: None,
                    value: Expr::Number(100),
                    source_line: 3,
                },
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        let tracker = TypeTracker::extract_types_from_module(&module);
        let x_type = tracker.get_var_type("x").unwrap();
        assert_eq!(x_type.name, "i16");
        assert!(x_type.signed);
    }

    #[test]
    fn test_extract_multiple_types() {
        let module = Module {
            items: vec![
                Item::Const {
                    name: "MAX_U8".to_string(),
                    type_annotation: Some("u8".to_string()),
                    value: Expr::Number(255),
                    source_line: 1,
                },
                Item::GlobalLet {
                    name: "counter".to_string(),
                    type_annotation: Some("i16".to_string()),
                    value: Expr::Number(0),
                    source_line: 2,
                },
                Item::GlobalLet {
                    name: "untyped".to_string(),
                    type_annotation: None,
                    value: Expr::Number(42),
                    source_line: 3,
                },
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        let tracker = TypeTracker::extract_types_from_module(&module);
        assert_eq!(tracker.len(), 3);

        assert_eq!(tracker.get_var_type("MAX_U8").unwrap().name, "u8");
        assert_eq!(tracker.get_var_type("counter").unwrap().name, "i16");
        assert_eq!(tracker.get_var_type("untyped").unwrap().name, "i16");
    }

    #[test]
    fn test_validate_types() {
        let mut tracker = TypeTracker::new();
        tracker.track_var("x".to_string(), VarType::from_str("u8").unwrap());
        tracker.track_var("y".to_string(), VarType::from_str("i16").unwrap());

        assert!(tracker.validate_types().is_ok());
    }
}
