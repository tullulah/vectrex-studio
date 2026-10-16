//! VPy Linker: Phase 7 of buildtools compiler pipeline (CRITICAL)
//!
//! **Single source of truth for final addresses and relocations**
//!
//! Combines object files (.vo), applies relocations, and produces final binary.
//! This is the ONLY phase that calculates final addresses - all other phases
//! use relative references and symbols.
//!
//! # Module Structure
//!
//! - `object.rs`: Object file format (.vo files)
//! - `error.rs`: Error types
//! - `relocation.rs`: Apply relocation records
//! - `linker.rs`: Main linking algorithm
//! - `layout.rs`: Memory layout decisions
//!
//! # Input
//! `Vec<VectrexObject>` (object files with relocation tables from Phase 6)
//!
//! # Output
//! `LinkedBinary` (final binary with symbol table and relocation info for PDB)

pub mod error;
pub mod layout;
pub mod linker;
pub mod object;      // Object file format (.vo)
pub mod relocation;
pub mod resolver;    // Symbol resolution (4-step algorithm)
pub mod bank_layout; // Multibank ROM integration
pub mod multi_bank_linker; // Phase 6.7: Multi-bank ROM generation
pub mod sizing;      // Measured function sizes for the bank allocator (generate → assemble → measure)

pub use error::{LinkerError, LinkerResult};
pub use object::{
    VectrexObject, ObjectHeader, Section, SectionType,
    Symbol, SymbolScope, SymbolType, SymbolTable,
    Relocation, RelocationType, DebugInfo,
    TargetArch, ObjectFlags,
    OBJECT_MAGIC, OBJECT_FORMAT_VERSION,
};
pub use resolver::{SymbolResolver, GlobalSymbolTable, ResolvedSymbol};
pub use bank_layout::{BankConfig, MultibankLayout, BankData, SectionAssignment};
pub use multi_bank_linker::MultiBankLinker;

/// Multi-bank ROM output
#[derive(Debug, Clone)]
pub struct MultiROM {
    /// Complete ROM data (all banks concatenated)
    pub rom_data: Vec<u8>,
    
    /// Bank configuration
    pub bank_config: vpy_codegen::BankConfig,
    
    /// Symbol table (for PDB generation)
    pub symbols: std::collections::HashMap<String, SymbolLocation>,
}

#[derive(Debug, Clone)]
pub struct SymbolLocation {
    pub bank_id: usize,
    pub offset: u16,
    pub absolute_address: u32,
}

/// Link assembled bank binaries into final ROM
pub fn link_unified_asm(
    generated: &vpy_codegen::GeneratedASM,
    binaries: Vec<vpy_assembler::BankBinary>,
) -> LinkerResult<MultiROM> {
    let bank_config = &generated.bank_config;
    let total_size = bank_config.rom_total_size;
    
    // Create empty ROM filled with 0xFF (typical ROM fill pattern)
    let mut rom_data = vec![0xFF; total_size];
    
    // Map to store symbol locations
    let mut symbols = std::collections::HashMap::new();
    
    // Process each bank binary
    for binary in &binaries {
        let bank_offset = binary.bank_id * bank_config.rom_bank_size;
        
        // Ensure bank fits in ROM
        if bank_offset + binary.bytes.len() > total_size {
            return Err(LinkerError::BinaryTooLarge {
                size: bank_offset + binary.bytes.len(),
                limit: total_size,
            });
        }
        
        // Copy bank data into ROM
        rom_data[bank_offset..bank_offset + binary.bytes.len()]
            .copy_from_slice(&binary.bytes);
        
        // Record symbol locations with bank info
        for (name, def) in &binary.symbols {
            symbols.insert(name.clone(), SymbolLocation {
                bank_id: binary.bank_id,
                offset: def.offset,
                absolute_address: (bank_offset + def.offset as usize) as u32,
            });
        }
    }
    
    Ok(MultiROM {
        rom_data,
        bank_config: bank_config.clone(),
        symbols,
    })
}

/// Single-bank compatibility wrapper
#[derive(Debug, Clone)]
pub struct LinkedBinary {
    pub binary: Vec<u8>,
    pub symbols: std::collections::HashMap<String, u32>,
    pub sections: Vec<LinkedSection>,
}

/// Section info in linked binary (distinct from object::Section)
#[derive(Debug, Clone)]
pub struct LinkedSection {
    pub name: String,
    pub start: u32,
    pub size: usize,
}

/// Load `.vo` object files from disk and link them into a single-bank binary.
pub fn link_object_files(paths: Vec<String>) -> LinkerResult<LinkedBinary> {
    if paths.is_empty() {
        return Err(LinkerError::Generic("No object files to link".to_string()));
    }

    let mut objects = Vec::new();
    for path in &paths {
        let obj = VectrexObject::load(std::path::Path::new(path))
            .map_err(|e| LinkerError::Error(format!("Failed to load '{}': {}", path, e)))?;
        objects.push(obj);
    }

    linker::link(objects, 0x0000)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_link_object_files_empty() {
        assert!(link_object_files(vec![]).is_err());
    }

    #[test]
    fn test_link_object_files_missing_path() {
        assert!(link_object_files(vec!["/nonexistent/path.vo".to_string()]).is_err());
    }
}
