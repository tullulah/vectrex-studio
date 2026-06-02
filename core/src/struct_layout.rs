/// Struct layout computation and validation
/// 
/// This module handles:
/// - Computing field offsets within structs
/// - Calculating total struct size
/// - Validating struct definitions

use crate::ast::StructDef;
use std::collections::HashMap;

/// Layout information for a struct
#[derive(Clone, Debug)]
pub struct StructLayout {
    pub name: String,
    pub fields: Vec<FieldLayout>,
    pub total_size: usize,
}

/// Layout information for a single field
#[derive(Clone, Debug)]
pub struct FieldLayout {
    pub name: String,
    pub offset: usize,
    pub size: usize,
}

impl StructLayout {
    /// Compute layout for a struct definition
    /// 
    /// Currently assumes all fields are 2-byte integers (M6809 word size)
    /// Future: could parse type annotations to support different sizes
    pub fn from_struct_def(def: &StructDef) -> Result<Self, String> {
        // Validate no duplicate field names
        let mut seen_fields = std::collections::HashSet::new();
        for field in &def.fields {
            if !seen_fields.insert(&field.name) {
                return Err(format!(
                    "Duplicate field '{}' in struct '{}' (line {})",
                    field.name, def.name, field.source_line
                ));
            }
        }

        // Compute field layouts
        let mut fields = Vec::new();
        let mut current_offset = 0;
        
        for field in &def.fields {
            // For now, all fields are 2 bytes (16-bit integers)
            // Future: parse type_annotation to determine size
            let size = 2;
            
            fields.push(FieldLayout {
                name: field.name.clone(),
                offset: current_offset,
                size,
            });
            
            current_offset += size;
        }

        Ok(StructLayout {
            name: def.name.clone(),
            fields,
            total_size: current_offset,
        })
    }

    /// Get field layout by name
    pub fn get_field(&self, field_name: &str) -> Option<&FieldLayout> {
        self.fields.iter().find(|f| f.name == field_name)
    }

    /// Get field offset by name
    pub fn field_offset(&self, field_name: &str) -> Option<usize> {
        self.get_field(field_name).map(|f| f.offset)
    }
}

/// Struct registry - maps struct names to their layouts
pub type StructRegistry = HashMap<String, StructLayout>;

/// Build struct registry from module items
pub fn build_struct_registry(items: &[crate::ast::Item]) -> Result<StructRegistry, String> {
    let mut registry = StructRegistry::new();
    
    for item in items {
        if let crate::ast::Item::StructDef(def) = item {
            // Check for duplicate struct definitions
            if registry.contains_key(&def.name) {
                return Err(format!(
                    "Duplicate struct definition '{}' at line {}",
                    def.name, def.source_line
                ));
            }
            
            // Compute layout
            let layout = StructLayout::from_struct_def(def)?;
            registry.insert(def.name.clone(), layout);
        }
    }
    
    Ok(registry)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ast::{StructDef, FieldDef};

    #[test]
    fn test_simple_struct_layout() {
        let def = StructDef {
            name: "Point".to_string(),
            fields: vec![
                FieldDef { name: "x".to_string(), type_annotation: Some("int".to_string()), source_line: 1 },
                FieldDef { name: "y".to_string(), type_annotation: Some("int".to_string()), source_line: 2 },
            ],
            source_line: 1,
            constructor: None,
            methods: vec![],
        };

        let layout = StructLayout::from_struct_def(&def).unwrap();
        assert_eq!(layout.name, "Point");
        assert_eq!(layout.total_size, 4); // 2 bytes per field
        assert_eq!(layout.fields.len(), 2);
        assert_eq!(layout.field_offset("x"), Some(0));
        assert_eq!(layout.field_offset("y"), Some(2));
    }

    #[test]
    fn test_duplicate_field_error() {
        let def = StructDef {
            name: "BadStruct".to_string(),
            fields: vec![
                FieldDef { name: "x".to_string(), type_annotation: None, source_line: 1 },
                FieldDef { name: "x".to_string(), type_annotation: None, source_line: 2 },
            ],
            source_line: 1,
            constructor: None,
            methods: vec![],
        };

        let result = StructLayout::from_struct_def(&def);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Duplicate field 'x'"));
    }

    #[test]
    fn test_struct_registry() {
        use crate::ast::Item;
        
        let items = vec![
            Item::StructDef(StructDef {
                name: "Point".to_string(),
                fields: vec![
                    FieldDef { name: "x".to_string(), type_annotation: None, source_line: 1 },
                    FieldDef { name: "y".to_string(), type_annotation: None, source_line: 2 },
                ],
                source_line: 1,
                constructor: None,
                methods: vec![],
            }),
            Item::StructDef(StructDef {
                name: "Rect".to_string(),
                fields: vec![
                    FieldDef { name: "width".to_string(), type_annotation: None, source_line: 1 },
                    FieldDef { name: "height".to_string(), type_annotation: None, source_line: 2 },
                ],
                source_line: 5,
                constructor: None,
                methods: vec![],
            }),
        ];

        let registry = build_struct_registry(&items).unwrap();
        assert_eq!(registry.len(), 2);
        assert!(registry.contains_key("Point"));
        assert!(registry.contains_key("Rect"));
        assert_eq!(registry.get("Point").unwrap().total_size, 4);
    }
}
