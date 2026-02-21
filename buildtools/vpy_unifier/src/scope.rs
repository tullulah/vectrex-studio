//! Scope management for variables, functions, and imports
//!
//! Tracks variable definitions, function scopes, and import namespaces

use std::collections::HashMap;
use crate::types::VarType;

/// Represents a scope level (module, function, block)
#[derive(Debug, Clone)]
pub struct Scope {
    /// Variables defined in this scope, mapped to their types
    pub variables: HashMap<String, VarType>,
    /// Functions defined in this scope
    pub functions: HashMap<String, String>,
    /// Parent scope (if nested)
    pub parent: Option<Box<Scope>>,
}

impl Scope {
    /// Create a new empty scope
    pub fn new() -> Self {
        Scope {
            variables: HashMap::new(),
            functions: HashMap::new(),
            parent: None,
        }
    }

    /// Create a child scope with parent reference
    pub fn child(&self) -> Self {
        Scope {
            variables: HashMap::new(),
            functions: HashMap::new(),
            parent: Some(Box::new(self.clone())),
        }
    }

    /// Look up a variable type in this or parent scopes
    pub fn lookup_var(&self, name: &str) -> Option<VarType> {
        if let Some(var_type) = self.variables.get(name) {
            return Some(*var_type);
        }
        if let Some(parent) = &self.parent {
            return parent.lookup_var(name);
        }
        None
    }

    /// Check if a symbol (variable or function) is defined in this or parent scopes
    pub fn lookup(&self, name: &str) -> Option<String> {
        if self.variables.contains_key(name) {
            return Some(name.to_string());
        }
        if let Some(func) = self.functions.get(name) {
            return Some(func.clone());
        }
        if let Some(parent) = &self.parent {
            return parent.lookup(name);
        }
        None
    }

    /// Define a variable in this scope with a type
    pub fn define_var(&mut self, name: String, var_type: VarType) {
        self.variables.insert(name, var_type);
    }

    /// Define a function in this scope
    pub fn define_func(&mut self, name: String, signature: String) {
        self.functions.insert(name, signature);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scope_creation() {
        let scope = Scope::new();
        assert!(scope.variables.is_empty());
        assert!(scope.functions.is_empty());
    }

    #[test]
    fn test_variable_definition() {
        let mut scope = Scope::new();
        scope.define_var("x".to_string(), VarType::from_str("u8").unwrap());
        assert!(scope.lookup("x").is_some());
        assert!(scope.lookup_var("x").is_some());
    }

    #[test]
    fn test_scope_nesting() {
        let mut parent = Scope::new();
        parent.define_var("x".to_string(), VarType::from_str("u16").unwrap());

        let child = parent.child();
        assert!(child.lookup("x").is_some());
        assert!(child.lookup_var("x").is_some());
    }

    #[test]
    fn test_lookup_var_type() {
        let mut scope = Scope::new();
        scope.define_var("x".to_string(), VarType::from_str("u8").unwrap());
        scope.define_var("y".to_string(), VarType::from_str("i16").unwrap());

        let x_type = scope.lookup_var("x").unwrap();
        assert_eq!(x_type.name, "u8");
        assert_eq!(x_type.size_bytes, 1);

        let y_type = scope.lookup_var("y").unwrap();
        assert_eq!(y_type.name, "i16");
        assert_eq!(y_type.size_bytes, 2);
    }

    #[test]
    fn test_lookup_var_defaults_to_i16() {
        let mut scope = Scope::new();
        scope.define_var("z".to_string(), VarType::default_i16());

        let z_type = scope.lookup_var("z").unwrap();
        assert_eq!(z_type.name, "i16");
        assert_eq!(z_type.size_bytes, 2);
        assert!(z_type.signed);
    }

    #[test]
    fn test_lookup_nonexistent_var() {
        let scope = Scope::new();
        assert!(scope.lookup_var("nonexistent").is_none());
    }
}
