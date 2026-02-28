//! Compilation Context for M6809 Codegen
//!
//! Provides thread-local context for sharing information across expression compilation
//! without needing to pass parameters through every function call.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};

/// Variable size metadata (bytes allocated + signedness)
/// Used to determine correct load/store instructions and array stride
#[derive(Debug, Clone, Copy)]
pub struct VarSize {
    /// Bytes allocated: 1 for u8/i8, 2 for u16/i16
    pub bytes: usize,
    /// Whether type is signed: true for i8/i16, false for u8/u16
    pub signed: bool,
}

impl VarSize {
    /// Default to 16-bit signed (backward compatible)
    pub fn default_i16() -> Self {
        VarSize {
            bytes: 2,
            signed: true,
        }
    }
}

thread_local! {
    /// Set of array names that are mutable (GlobalLet, stored in RAM)
    /// Const arrays are not in this set (stored in ROM)
    static MUTABLE_ARRAYS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());

    /// Map of variable names (lowercase, no VAR_ prefix) to their size metadata
    /// Used to emit correct load/store instructions and allocation sizes
    static VAR_SIZES: RefCell<HashMap<String, VarSize>> = RefCell::new(HashMap::new());

    /// Map of const names (lowercase) to their compile-time integer values.
    /// Populated before codegen so emit_simple_expr can emit LDD #value instead of LDD >VAR_name.
    static CONST_VALUES: RefCell<HashMap<String, i64>> = RefCell::new(HashMap::new());
}

/// Initialize the mutable arrays context
/// Call this before compiling expressions
pub fn set_mutable_arrays(arrays: HashSet<String>) {
    MUTABLE_ARRAYS.with(|ma| {
        *ma.borrow_mut() = arrays;
    });
}

/// Check if an array name is mutable (stored in RAM)
/// Returns true if the array was defined with 'let' (GlobalLet)
/// Returns false if it's const (stored in ROM)
pub fn is_mutable_array(name: &str) -> bool {
    MUTABLE_ARRAYS.with(|ma| {
        ma.borrow().contains(name)
    })
}

/// Register a variable's size metadata
/// Call this during allocation for every user variable and local
/// name: lowercase variable name (no VAR_ prefix)
/// bytes: 1 for u8/i8, 2 for u16/i16
/// signed: true for i8/i16, false for u8/u16
pub fn set_var_size(name: &str, bytes: usize, signed: bool) {
    VAR_SIZES.with(|vs| {
        vs.borrow_mut().insert(name.to_string(), VarSize { bytes, signed });
    });
}

/// Look up a variable's size metadata
/// Returns the registered size, or default i16 (2 bytes, signed) if not found
/// name: lowercase variable name (no VAR_ prefix)
pub fn get_var_size(name: &str) -> VarSize {
    VAR_SIZES.with(|vs| {
        vs.borrow()
            .get(name)
            .copied()
            .unwrap_or_else(VarSize::default_i16)
    })
}

/// Clear the variable sizes context
fn clear_var_sizes() {
    VAR_SIZES.with(|vs| {
        vs.borrow_mut().clear();
    });
}

/// Register a compile-time const value.
/// name: lowercase const name (no VAR_ prefix), value: integer literal
pub fn set_const_value(name: &str, value: i64) {
    CONST_VALUES.with(|cv| {
        cv.borrow_mut().insert(name.to_lowercase(), value);
    });
}

/// Look up a compile-time const value.
/// Returns Some(value) if the name is a const, None if it is a runtime variable.
pub fn get_const_value(name: &str) -> Option<i64> {
    CONST_VALUES.with(|cv| {
        cv.borrow().get(&name.to_lowercase()).copied()
    })
}

/// Clear all compilation context (mutable arrays, variable sizes, and const values)
pub fn clear_context() {
    MUTABLE_ARRAYS.with(|ma| {
        ma.borrow_mut().clear();
    });
    clear_var_sizes();
    CONST_VALUES.with(|cv| {
        cv.borrow_mut().clear();
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_var_size_u8() {
        clear_context();
        set_var_size("health", 1, false);
        let size = get_var_size("health");
        assert_eq!(size.bytes, 1);
        assert!(!size.signed);
    }

    #[test]
    fn test_var_size_i8() {
        clear_context();
        set_var_size("counter", 1, true);
        let size = get_var_size("counter");
        assert_eq!(size.bytes, 1);
        assert!(size.signed);
    }

    #[test]
    fn test_var_size_u16() {
        clear_context();
        set_var_size("score", 2, false);
        let size = get_var_size("score");
        assert_eq!(size.bytes, 2);
        assert!(!size.signed);
    }

    #[test]
    fn test_var_size_i16() {
        clear_context();
        set_var_size("offset", 2, true);
        let size = get_var_size("offset");
        assert_eq!(size.bytes, 2);
        assert!(size.signed);
    }

    #[test]
    fn test_var_size_default_missing() {
        clear_context();
        let size = get_var_size("nonexistent");
        assert_eq!(size.bytes, 2);
        assert!(size.signed); // default to i16
    }

    #[test]
    fn test_clear_var_sizes() {
        clear_context();
        set_var_size("x", 1, false);
        set_var_size("y", 2, true);
        clear_context();

        // After clear, all lookups should return default
        let x = get_var_size("x");
        assert_eq!(x.bytes, 2);
        assert!(x.signed);

        let y = get_var_size("y");
        assert_eq!(y.bytes, 2);
        assert!(y.signed);
    }

    #[test]
    fn test_var_size_default_i16() {
        let def = VarSize::default_i16();
        assert_eq!(def.bytes, 2);
        assert!(def.signed);
    }
}
