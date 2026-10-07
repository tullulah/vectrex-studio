use thiserror::Error;

#[derive(Debug, Error)]
pub enum LinkerError {
    #[error("Linker not yet implemented")]
    NotImplemented,

    #[error("Duplicate symbol '{symbol}' defined in:\n  - {first} (first definition)\n  - {second} (duplicate)")]
    DuplicateSymbol {
        symbol: String,
        first: String,
        second: String,
    },

    #[error("Undefined symbols:\n{}", format_undefined(.symbols))]
    UndefinedSymbols {
        symbols: Vec<(String, String)>,  // (symbol_name, source_file)
    },

    #[error("Symbol '{symbol}' not found")]
    SymbolNotFound {
        symbol: String,
    },

    #[error("Invalid section index {index}")]
    InvalidSection {
        index: usize,
    },

    #[error("Relocation at offset {offset} exceeds section size {size}")]
    RelocationOutOfBounds {
        offset: usize,
        size: usize,
    },

    #[error("CrossBank relocation not yet implemented for symbol '{symbol}'")]
    CrossBankNotImplemented {
        symbol: String,
    },

    #[error("Binary too large: {size} bytes, {} bytes over the {limit}-byte ROM", .size.saturating_sub(*.limit))]
    BinaryTooLarge { 
        size: usize, 
        limit: usize 
    },
    
    #[error("Linker error: {0}")]
    Error(String),

    #[error("{0}")]
    Generic(String),
}

fn format_undefined(symbols: &[(String, String)]) -> String {
    symbols
        .iter()
        .map(|(name, file)| format!("  - '{}' in {}", name, file))
        .collect::<Vec<_>>()
        .join("\n")
}

pub type LinkerResult<T> = Result<T, LinkerError>;
