//! Symbol resolver for renaming symbols across modules
//!
//! Handles the mapping of module-qualified symbols to unified names

use std::collections::HashMap;

/// Symbol resolver for module-aware naming
///
/// Maps module names to prefixes and tracks symbol origination
#[derive(Debug, Clone)]
pub struct SymbolResolver {
    /// Module name -> uppercase prefix (e.g., "input" -> "INPUT")
    module_prefixes: HashMap<String, String>,
}

impl SymbolResolver {
    /// Create a new symbol resolver
    pub fn new() -> Self {
        SymbolResolver {
            module_prefixes: HashMap::new(),
        }
    }

    /// Register a module and get its prefix
    ///
    /// Returns the prefix to use for symbols from this module.
    /// Entry module "main" gets no prefix, others get "MODULENAME_"
    pub fn register_module(&mut self, module_name: &str) -> String {
        if module_name == "main" {
            // Entry module: no prefix
            "".to_string()
        } else {
            // Other modules: UPPERCASE prefix
            let prefix = vpy_parser::symbols::module_prefix(module_name);
            self.module_prefixes
                .insert(module_name.to_string(), prefix.clone());
            prefix
        }
    }

    /// Get the prefix for a module
    pub fn get_module_prefix(&self, module_name: &str) -> String {
        if module_name == "main" {
            "".to_string()
        } else {
            self.module_prefixes
                .get(module_name)
                .cloned()
                .unwrap_or_else(|| vpy_parser::symbols::module_prefix(module_name))
        }
    }

    /// Resolve a symbol to its unified name
    ///
    /// # Arguments
    /// * `symbol` - The symbol name
    /// * `module` - The module it comes from
    ///
    /// # Returns
    /// The unified symbol name (with module prefix if applicable)
    pub fn resolve_symbol(&self, symbol: &str, module: &str) -> String {
        if self.get_module_prefix(module).is_empty() {
            // No prefix for main module - keep original case
            symbol.to_string()
        } else {
            // With prefix - uppercase prefix, original-case symbol (e.g., INPUT_get_input).
            // The one mangling function every phase uses.
            vpy_parser::symbols::mangle(module, symbol)
        }
    }

    /// Resolve a module-qualified symbol (e.g., "input.get_input")
    ///
    /// This is used when processing expressions like module.function()
    pub fn resolve_field_access(&self, module_name: &str, symbol_name: &str) -> String {
        self.resolve_symbol(symbol_name, module_name)
    }

    /// Get all registered modules
    pub fn modules(&self) -> Vec<String> {
        self.module_prefixes.keys().cloned().collect()
    }
}

impl Default for SymbolResolver {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_resolver_new() {
        let resolver = SymbolResolver::new();
        assert!(resolver.modules().is_empty());
    }

    #[test]
    fn test_register_main_module() {
        let mut resolver = SymbolResolver::new();
        let prefix = resolver.register_module("main");
        
        // Main module should have no prefix
        assert_eq!(prefix, "");
        assert_eq!(resolver.get_module_prefix("main"), "");
    }

    #[test]
    fn test_register_other_module() {
        let mut resolver = SymbolResolver::new();
        let prefix = resolver.register_module("input");
        
        // Other modules get uppercase prefix
        assert_eq!(prefix, "INPUT");
        assert_eq!(resolver.get_module_prefix("input"), "INPUT");
    }

    #[test]
    fn test_resolve_symbol_main() {
        let mut resolver = SymbolResolver::new();
        resolver.register_module("main");
        
        let resolved = resolver.resolve_symbol("get_input", "main");
        assert_eq!(resolved, "get_input");
    }

    #[test]
    fn test_resolve_symbol_imported() {
        let mut resolver = SymbolResolver::new();
        resolver.register_module("input");
        
        let resolved = resolver.resolve_symbol("get_input", "input");
        assert_eq!(resolved, "INPUT_get_input");
    }

    #[test]
    fn test_resolve_field_access() {
        let mut resolver = SymbolResolver::new();
        resolver.register_module("graphics");
        
        let resolved = resolver.resolve_field_access("graphics", "draw_square");
        assert_eq!(resolved, "GRAPHICS_draw_square");
    }

    #[test]
    fn test_multiple_modules() {
        let mut resolver = SymbolResolver::new();
        resolver.register_module("main");
        resolver.register_module("input");
        resolver.register_module("graphics");
        
        assert_eq!(resolver.resolve_symbol("func", "main"), "func");
        assert_eq!(resolver.resolve_symbol("func", "input"), "INPUT_func");
        assert_eq!(resolver.resolve_symbol("func", "graphics"), "GRAPHICS_func");
    }

    #[test]
    fn test_modules_list() {
        let mut resolver = SymbolResolver::new();
        resolver.register_module("main");
        resolver.register_module("input");
        resolver.register_module("graphics");
        
        let modules = resolver.modules();
        assert_eq!(modules.len(), 2); // main is not included in modules
        assert!(modules.contains(&"input".to_string()));
        assert!(modules.contains(&"graphics".to_string()));
    }
}
