use thiserror::Error;

#[derive(Debug, Error)]
pub enum BankAllocatorError {
    #[error("Code too large for single bank: {0} bytes")]
    CodeTooLarge(usize),

    #[error("Function too large: {0} ({1} bytes)")]
    FunctionTooLarge(String, usize),

    #[error("Circular dependency in call graph")]
    CircularDependency,

    /// The program's code does not fit the configured ROM. Every number is in bytes and
    /// comes from the sizes the allocator was given (measured from assembled code when
    /// the caller supplied them).
    #[error("{0}")]
    DoesNotFit(String),

    #[error("{0}")]
    Generic(String),
}

pub type BankAllocatorResult<T> = Result<T, BankAllocatorError>;
