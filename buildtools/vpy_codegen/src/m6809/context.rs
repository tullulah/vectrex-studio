//! Compilation Context for M6809 Codegen
//!
//! Provides thread-local context for sharing information across expression compilation
//! without needing to pass parameters through every function call.

use std::cell::RefCell;
use std::collections::{HashMap, HashSet};

/// Variable size metadata (bytes allocated + signedness)
/// Used to determine correct load/store instructions and array stride
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
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

    /// Size of a declared type annotation: u8/i8 = 1 byte, u16/i16 = 2, none = i16.
    pub fn from_annotation(type_annotation: &Option<String>) -> Self {
        match type_annotation.as_deref() {
            Some("u8") => VarSize { bytes: 1, signed: false },
            Some("i8") => VarSize { bytes: 1, signed: true },
            Some("u16") => VarSize { bytes: 2, signed: false },
            _ => VarSize::default_i16(),
        }
    }

    /// Type name for messages.
    pub fn type_name(self) -> &'static str {
        match (self.bytes, self.signed) {
            (1, false) => "u8",
            (1, true) => "i8",
            (_, false) => "u16",
            (_, true) => "i16",
        }
    }
}

thread_local! {
    /// Set of array names that are mutable (GlobalLet, stored in RAM)
    /// Const arrays are not in this set (stored in ROM)
    static MUTABLE_ARRAYS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());

    /// Set of global const array names (Item::Const with a list literal, stored in ROM)
    static CONST_ARRAYS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());

    /// Map of variable names (lowercase, no VAR_ prefix) to their size metadata
    /// Used to emit correct load/store instructions and allocation sizes
    static VAR_SIZES: RefCell<HashMap<String, VarSize>> = RefCell::new(HashMap::new());

    /// Map of const names (lowercase) to their compile-time integer values.
    /// Populated before codegen so emit_simple_expr can emit LDD #value instead of LDD >VAR_name.
    static CONST_VALUES: RefCell<HashMap<String, i64>> = RefCell::new(HashMap::new());

    /// Map of function names (uppercase) to their frame group (from @frame(N) decorator).
    /// Used by generate_statement to wrap JSR calls with FRAME_PARITY guard.
    static FRAME_GROUPS: RefCell<HashMap<String, u8>> = RefCell::new(HashMap::new());

    /// Interleaved frames count (2 or 3). 0 means disabled.
    static INTERLEAVED_N: RefCell<u8> = RefCell::new(0);

    /// Map of current function parameter names (lowercase) → ARG index (0-4).
    /// When set, identifiers matching a param are emitted as VAR_ARGn instead of VAR_NAME.
    static CURRENT_PARAMS: RefCell<HashMap<String, usize>> = RefCell::new(HashMap::new());

    /// Element type of every array PARAMETER, per function: m6809 label (upper-case)
    /// → parameter name (lower-case) → element size. Filled by `array_params::analyze`
    /// from the arrays passed at the call sites. Absent = 16-bit (the default).
    static PARAM_ARRAY_ELEMS: RefCell<HashMap<String, HashMap<String, VarSize>>> = RefCell::new(HashMap::new());

    /// m6809 label of the function whose body is being generated ("" outside one).
    static CURRENT_FUNCTION: RefCell<String> = const { RefCell::new(String::new()) };
}

/// Where the elements of an indexable name live.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ArrayBase {
    /// A global array: its data label is the base address (link-time constant).
    Label(String),
    /// A parameter holding an array's base address: the label of its 16-bit slot.
    Pointer(String),
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

/// Register the global const arrays (Item::Const with a list literal, stored in ROM)
pub fn set_const_arrays(arrays: HashSet<String>) {
    CONST_ARRAYS.with(|ca| {
        *ca.borrow_mut() = arrays;
    });
}

/// Base address label of a global array, or None if `name` is not a global array
/// (or is shadowed by a parameter of the function being generated).
///
/// A global array name used as a value evaluates to its base address, a link-time
/// constant: `VAR_<NAME>_DATA` (RAM copy of a mutable array) or `ARRAY_<NAME>_DATA`
/// (ROM data of a const array). There is no pointer variable in RAM.
pub fn global_array_base_label(name: &str) -> Option<String> {
    if get_param_index(name).is_some() {
        return None;
    }
    if is_mutable_array(name) {
        Some(format!("VAR_{}_DATA", name.to_uppercase()))
    } else if CONST_ARRAYS.with(|ca| ca.borrow().contains(name)) {
        Some(format!("ARRAY_{}_DATA", name.to_uppercase()))
    } else {
        None
    }
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
    // A parameter lives in a 16-bit VAR_ARGn slot whatever a global of the same
    // name is declared as.
    if get_param_index(name).is_some() {
        return VarSize::default_i16();
    }
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
    // A parameter of the function being generated shadows a const of the same
    // name (names are case-insensitive: parameter `b` vs `const B`).
    if get_param_index(name).is_some() {
        return None;
    }
    CONST_VALUES.with(|cv| {
        cv.borrow().get(&name.to_lowercase()).copied()
    })
}

/// Set the frame groups map (function name uppercase → frame group index)
pub fn set_frame_groups(groups: HashMap<String, u8>, n: u8) {
    FRAME_GROUPS.with(|fg| {
        *fg.borrow_mut() = groups;
    });
    INTERLEAVED_N.with(|inl| {
        *inl.borrow_mut() = n;
    });
}

/// Look up the frame group for a function name (uppercase)
/// Returns Some(n) if decorated with @frame(n), None if always runs
pub fn get_frame_group(name: &str) -> Option<u8> {
    FRAME_GROUPS.with(|fg| {
        fg.borrow().get(name).copied()
    })
}

/// Get the interleaved_frames N value (0 = disabled)
pub fn get_interleaved_n() -> u8 {
    INTERLEAVED_N.with(|inl| *inl.borrow())
}

/// Set the current function's parameter mapping (param name lowercase → ARG index).
/// Call at the start of generating a user function with parameters.
pub fn set_current_params(params: &[String]) {
    CURRENT_PARAMS.with(|cp| {
        let mut map = cp.borrow_mut();
        map.clear();
        // Keep in sync with MAX_USER_ARGS in expressions.rs.
        for (i, p) in params.iter().enumerate().take(8) {
            map.insert(p.to_lowercase(), i);
        }
    });
}

/// Clear the current function parameter mapping.
/// Call after generating a user function body.
pub fn clear_current_params() {
    CURRENT_PARAMS.with(|cp| {
        cp.borrow_mut().clear();
    });
}

/// Look up whether a variable name is a function parameter.
/// Returns Some(index) if it is (should use VAR_ARGn), None if not.
pub fn get_param_index(name: &str) -> Option<usize> {
    CURRENT_PARAMS.with(|cp| {
        cp.borrow().get(&name.to_lowercase()).copied()
    })
}

/// Register the element type of every array parameter (see `array_params`).
pub fn set_param_array_elems(map: HashMap<String, HashMap<String, VarSize>>) {
    PARAM_ARRAY_ELEMS.with(|m| *m.borrow_mut() = map);
}

/// Record the m6809 label of the function whose body is being generated.
pub fn set_current_function(label: &str) {
    CURRENT_FUNCTION.with(|f| *f.borrow_mut() = label.to_string());
}

/// How to index `name`: its base address and element size, or None when `name`
/// is neither a global array nor a parameter of the current function.
///
/// A parameter is a pointer to the array the caller passed. Its element type
/// comes from the arrays passed at the call sites; with none known it is 16-bit.
pub fn resolve_array(name: &str) -> Option<(ArrayBase, VarSize)> {
    if let Some(idx) = get_param_index(name) {
        let elem = CURRENT_FUNCTION.with(|f| {
            PARAM_ARRAY_ELEMS.with(|m| {
                m.borrow()
                    .get(f.borrow().as_str())
                    .and_then(|params| params.get(&name.to_lowercase()).copied())
            })
        });
        return Some((
            ArrayBase::Pointer(format!("VAR_ARG{}", idx)),
            elem.unwrap_or_else(VarSize::default_i16),
        ));
    }
    let label = global_array_base_label(name)?;
    Some((ArrayBase::Label(label), get_var_size(name)))
}

/// Clear all compilation context (mutable arrays, variable sizes, const values, frame groups)
pub fn clear_context() {
    MUTABLE_ARRAYS.with(|ma| {
        ma.borrow_mut().clear();
    });
    CONST_ARRAYS.with(|ca| {
        ca.borrow_mut().clear();
    });
    clear_var_sizes();
    CONST_VALUES.with(|cv| {
        cv.borrow_mut().clear();
    });
    FRAME_GROUPS.with(|fg| {
        fg.borrow_mut().clear();
    });
    INTERLEAVED_N.with(|inl| {
        *inl.borrow_mut() = 0;
    });
    CURRENT_PARAMS.with(|cp| {
        cp.borrow_mut().clear();
    });
    PARAM_ARRAY_ELEMS.with(|m| m.borrow_mut().clear());
    CURRENT_FUNCTION.with(|f| f.borrow_mut().clear());
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
