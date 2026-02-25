//! Type system infrastructure for VPy
//!
//! Provides structured type information for variables, including:
//! - Type name (u8, i8, u16, i16)
//! - Size in bytes (1 or 2)
//! - Signedness (signed/unsigned)

/// Represents a variable type with size and signedness information
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct VarType {
    /// Type name: "u8", "i8", "u16", "i16"
    pub name: &'static str,
    /// Size in bytes
    pub size_bytes: usize,
    /// Whether the type is signed
    pub signed: bool,
}

impl VarType {
    /// Create the default type (i16 - 16-bit signed)
    /// Used for untyped variables for backward compatibility
    pub fn default_i16() -> Self {
        VarType {
            name: "i16",
            size_bytes: 2,
            signed: true,
        }
    }

    /// Parse a type name string and return VarType
    /// Returns Some(VarType) for valid types, None for invalid
    pub fn from_str(type_name: &str) -> Option<VarType> {
        match type_name {
            "u8" => Some(VarType {
                name: "u8",
                size_bytes: 1,
                signed: false,
            }),
            "i8" => Some(VarType {
                name: "i8",
                size_bytes: 1,
                signed: true,
            }),
            "u16" => Some(VarType {
                name: "u16",
                size_bytes: 2,
                signed: false,
            }),
            "i16" => Some(VarType {
                name: "i16",
                size_bytes: 2,
                signed: true,
            }),
            _ => None,
        }
    }

    /// Check if a type name is valid
    pub fn is_valid_type_name(name: &str) -> bool {
        matches!(name, "u8" | "i8" | "u16" | "i16")
    }

    /// Get the default type for an optional type annotation
    /// If annotation is None, returns default i16
    /// If annotation is Some, converts to VarType
    pub fn from_optional(type_annotation: &Option<String>) -> Option<VarType> {
        match type_annotation {
            Some(name) => VarType::from_str(name),
            None => Some(VarType::default_i16()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_var_type_u8() {
        let vt = VarType::from_str("u8").unwrap();
        assert_eq!(vt.name, "u8");
        assert_eq!(vt.size_bytes, 1);
        assert!(!vt.signed);
    }

    #[test]
    fn test_var_type_i8() {
        let vt = VarType::from_str("i8").unwrap();
        assert_eq!(vt.name, "i8");
        assert_eq!(vt.size_bytes, 1);
        assert!(vt.signed);
    }

    #[test]
    fn test_var_type_u16() {
        let vt = VarType::from_str("u16").unwrap();
        assert_eq!(vt.name, "u16");
        assert_eq!(vt.size_bytes, 2);
        assert!(!vt.signed);
    }

    #[test]
    fn test_var_type_i16() {
        let vt = VarType::from_str("i16").unwrap();
        assert_eq!(vt.name, "i16");
        assert_eq!(vt.size_bytes, 2);
        assert!(vt.signed);
    }

    #[test]
    fn test_var_type_default_i16() {
        let vt = VarType::default_i16();
        assert_eq!(vt.name, "i16");
        assert_eq!(vt.size_bytes, 2);
        assert!(vt.signed);
    }

    #[test]
    fn test_var_type_invalid_name() {
        assert!(VarType::from_str("u32").is_none());
        assert!(VarType::from_str("f32").is_none());
        assert!(VarType::from_str("invalid").is_none());
    }

    #[test]
    fn test_var_type_is_valid_type_name() {
        assert!(VarType::is_valid_type_name("u8"));
        assert!(VarType::is_valid_type_name("i8"));
        assert!(VarType::is_valid_type_name("u16"));
        assert!(VarType::is_valid_type_name("i16"));
        assert!(!VarType::is_valid_type_name("u32"));
        assert!(!VarType::is_valid_type_name("invalid"));
    }

    #[test]
    fn test_var_type_from_optional_some() {
        let vt = VarType::from_optional(&Some("u8".to_string())).unwrap();
        assert_eq!(vt.name, "u8");
        assert_eq!(vt.size_bytes, 1);
    }

    #[test]
    fn test_var_type_from_optional_none() {
        let vt = VarType::from_optional(&None).unwrap();
        assert_eq!(vt.name, "i16");
        assert_eq!(vt.size_bytes, 2);
    }
}
