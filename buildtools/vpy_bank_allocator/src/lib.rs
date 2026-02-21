//! VPy Bank Allocator: Phase 4 of buildtools compiler pipeline
//!
//! Assigns functions to banks for multibank cartridges
//!
//! # Module Structure
//!
//! - `error.rs`: Error types
//! - `allocator.rs`: Main allocation algorithm
//! - `graph.rs`: Call graph analysis
//!
//! # Input
//! `UnifiedModule` (unified module from Phase 3)
//!
//! # Output
//! `BankLayout` (function-to-bank mapping for multibank or single bank)
//!
//! # Usage
//!
//! ```ignore
//! use vpy_bank_allocator::*;
//! use vpy_parser::Module;
//! 
//! // Build call graph from module
//! let graph = graph::CallGraph::from_module(&module);
//! 
//! // Configure banks (512KB multibank)
//! let config = allocator::BankConfig::multibank_512kb();
//! 
//! // Allocate functions to banks
//! let allocator = allocator::BankAllocator::new(config, graph);
//! let assignments = allocator.assign_banks()?;
//! 
//! // Create bank layout
//! let layout = BankLayout::from_assignments(assignments, 32, 16384);
//! ```

pub mod allocator;
pub mod error;
pub mod graph;
pub mod variable_sizer;

pub use error::{BankAllocatorError, BankAllocatorResult};
pub use allocator::{BankAllocator, BankConfig, BankStats};
pub use graph::{CallGraph, FunctionNode, CallEdge};
pub use variable_sizer::VariableSizer;

use std::collections::HashMap;

/// Layout of functions in banks
#[derive(Debug, Clone)]
pub struct BankLayout {
    /// Functions assigned to each bank
    pub banks: Vec<Vec<String>>,
    /// Total banks needed
    pub num_banks: usize,
    /// Bank size limit
    pub bank_size: usize,
}

impl BankLayout {
    /// Create bank layout from assignments
    pub fn from_assignments(
        assignments: HashMap<String, u8>,
        num_banks: usize,
        bank_size: usize,
    ) -> Self {
        // Initialize empty banks
        let mut banks = vec![Vec::new(); num_banks];
        
        // Place functions in their assigned banks
        for (func_name, bank_id) in assignments {
            if (bank_id as usize) < num_banks {
                banks[bank_id as usize].push(func_name);
            }
        }
        
        BankLayout {
            banks,
            num_banks,
            bank_size,
        }
    }
    
    /// Single bank layout (all functions in bank 0)
    pub fn single_bank(functions: Vec<String>) -> Self {
        BankLayout {
            banks: vec![functions],
            num_banks: 1,
            bank_size: 32768,
        }
    }
}

/// High-level API: Allocate functions to banks from module
///
/// # Arguments
/// * `module` - Unified module from Phase 3
/// * `config` - Bank configuration
///
/// # Returns
/// * `BankAllocatorResult<BankLayout>` - Bank layout or error
///
/// # Example
/// ```ignore
/// let config = BankConfig::multibank_512kb();
/// let layout = allocate_banks_from_module(&module, config)?;
/// ```
pub fn allocate_banks_from_module(
    module: &vpy_parser::Module,
    config: BankConfig,
) -> BankAllocatorResult<BankLayout> {
    // Build call graph
    let graph = CallGraph::from_module(module);
    
    // Allocate banks
    let allocator = BankAllocator::new(config.clone(), graph);
    let assignments = allocator.assign_banks()?;
    
    // Create layout
    let layout = BankLayout::from_assignments(
        assignments,
        config.rom_bank_count,
        config.rom_bank_size,
    );
    
    Ok(layout)
}

#[cfg(test)]
mod tests {
    use super::*;
    use vpy_parser::{Module, ModuleMeta, Item, Function};

    #[test]
    fn test_single_bank_layout() {
        let functions = vec!["main".to_string(), "loop".to_string()];
        let layout = BankLayout::single_bank(functions);
        
        assert_eq!(layout.num_banks, 1);
        assert_eq!(layout.banks[0].len(), 2);
    }
    
    #[test]
    fn test_from_assignments() {
        let mut assignments = HashMap::new();
        assignments.insert("func1".to_string(), 0);
        assignments.insert("func2".to_string(), 1);
        
        let layout = BankLayout::from_assignments(assignments, 2, 16384);
        
        assert_eq!(layout.num_banks, 2);
        assert_eq!(layout.banks[0], vec!["func1"]);
        assert_eq!(layout.banks[1], vec!["func2"]);
    }
    
    #[test]
    fn test_allocate_simple_module() {
        // Create minimal module
        let module = Module {
            items: vec![
                Item::Function(Function {
                    name: "main".to_string(),
                    line: 0,
                    params: vec![],
                    body: vec![],
                })
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };
        
        // Use multibank config with minimum 2 banks (1 code + 1 helpers)
        let config = BankConfig::new(32768, 16384); // 2 banks of 16KB each
        let layout = allocate_banks_from_module(&module, config).unwrap();
        
        assert_eq!(layout.num_banks, 2);
        assert!(layout.banks[0].contains(&"main".to_string()));
    }
}
