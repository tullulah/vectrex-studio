//! Variable memory sizing based on types
//!
//! Calculates memory usage for global variables and arrays based on their types

use std::collections::HashMap;
use vpy_unifier::TypeTracker;

/// Tracks memory usage of variables in banks
#[derive(Debug, Clone)]
pub struct VariableSizer {
    /// Size in bytes for each variable
    pub var_sizes: HashMap<String, usize>,
    /// Total variable memory used
    pub total_var_bytes: usize,
}

impl VariableSizer {
    /// Create a new variable sizer from a TypeTracker
    pub fn from_type_tracker(tracker: &TypeTracker) -> Self {
        let mut sizer = VariableSizer {
            var_sizes: HashMap::new(),
            total_var_bytes: 0,
        };

        for (name, var_type) in &tracker.var_types {
            // Size is based on VarType::size_bytes (1 or 2 bytes per variable)
            // TODO: In future, handle arrays with element count
            let size = var_type.size_bytes;
            sizer.var_sizes.insert(name.clone(), size);
            sizer.total_var_bytes += size;
        }

        sizer
    }

    /// Get size of a specific variable
    pub fn get_var_size(&self, name: &str) -> Option<usize> {
        self.var_sizes.get(name).copied()
    }

    /// Calculate remaining space in a bank after allocating variables
    pub fn remaining_space(&self, bank_size: usize) -> usize {
        if self.total_var_bytes > bank_size {
            0
        } else {
            bank_size - self.total_var_bytes
        }
    }

    /// Check if variables fit in a bank
    pub fn fits_in_bank(&self, bank_size: usize) -> bool {
        self.total_var_bytes <= bank_size
    }

    /// Get count of tracked variables
    pub fn var_count(&self) -> usize {
        self.var_sizes.len()
    }

    /// Get all tracked variable names
    pub fn var_names(&self) -> Vec<String> {
        self.var_sizes.keys().cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use vpy_unifier::VarType;

    #[test]
    fn test_variable_sizer_creation() {
        let tracker = TypeTracker::new();
        let sizer = VariableSizer::from_type_tracker(&tracker);
        assert_eq!(sizer.var_count(), 0);
        assert_eq!(sizer.total_var_bytes, 0);
    }

    #[test]
    fn test_u8_variable_sizing() {
        let mut tracker = TypeTracker::new();
        let u8_type = VarType::from_str("u8").unwrap();
        tracker.track_var("health".to_string(), u8_type);

        let sizer = VariableSizer::from_type_tracker(&tracker);
        assert_eq!(sizer.var_count(), 1);
        assert_eq!(sizer.total_var_bytes, 1);
        assert_eq!(sizer.get_var_size("health"), Some(1));
    }

    #[test]
    fn test_u16_variable_sizing() {
        let mut tracker = TypeTracker::new();
        let u16_type = VarType::from_str("u16").unwrap();
        tracker.track_var("score".to_string(), u16_type);

        let sizer = VariableSizer::from_type_tracker(&tracker);
        assert_eq!(sizer.var_count(), 1);
        assert_eq!(sizer.total_var_bytes, 2);
        assert_eq!(sizer.get_var_size("score"), Some(2));
    }

    #[test]
    fn test_mixed_variable_sizing() {
        let mut tracker = TypeTracker::new();
        tracker.track_var("health".to_string(), VarType::from_str("u8").unwrap());
        tracker.track_var("score".to_string(), VarType::from_str("u16").unwrap());
        tracker.track_var("counter".to_string(), VarType::from_str("i8").unwrap());
        tracker.track_var("offset".to_string(), VarType::from_str("i16").unwrap());

        let sizer = VariableSizer::from_type_tracker(&tracker);
        assert_eq!(sizer.var_count(), 4);
        // 1 + 2 + 1 + 2 = 6 bytes
        assert_eq!(sizer.total_var_bytes, 6);
    }

    #[test]
    fn test_remaining_space_in_bank() {
        let mut tracker = TypeTracker::new();
        tracker.track_var("x".to_string(), VarType::from_str("u16").unwrap());
        let sizer = VariableSizer::from_type_tracker(&tracker);

        let bank_size = 16384;
        let remaining = sizer.remaining_space(bank_size);
        assert_eq!(remaining, bank_size - 2);
    }

    #[test]
    fn test_fits_in_bank() {
        let mut tracker = TypeTracker::new();
        tracker.track_var("x".to_string(), VarType::from_str("u16").unwrap());
        let sizer = VariableSizer::from_type_tracker(&tracker);

        assert!(sizer.fits_in_bank(16384));
        assert!(sizer.fits_in_bank(2));
        assert!(!sizer.fits_in_bank(1)); // Only 2 bytes needed but only 1 available
    }
}
