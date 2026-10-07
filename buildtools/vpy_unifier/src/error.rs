use thiserror::Error;

/// A resolution error tied to a source location.
///
/// `module` is the module name (file stem); the CLI maps it back to the file
/// path when it prints the error (see [`Diagnostic::render`]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Diagnostic {
    pub module: String,
    pub line: usize,
    pub message: String,
}

impl Diagnostic {
    /// `path:line: error: message`
    pub fn render(&self, path: &str) -> String {
        format!("{}:{}: error: {}", path, self.line, self.message)
    }
}

impl std::fmt::Display for Diagnostic {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.render(&format!("{}.vpy", self.module)))
    }
}

fn render_all(diags: &[Diagnostic]) -> String {
    diags.iter().map(|d| d.to_string()).collect::<Vec<_>>().join("\n")
}

#[derive(Debug, Error)]
pub enum UnifierError {
    #[error("Unifier not yet implemented")]
    NotImplemented,

    #[error("Unresolved symbol: {0}")]
    UnresolvedSymbol(String),

    #[error("Import not found: {0}")]
    ImportNotFound(String),

    #[error("Circular dependency: {0}")]
    CircularDependency(String),

    #[error("Symbol conflict: {0}")]
    SymbolConflict(String),

    /// One or more imports / `module.symbol` references that do not resolve.
    #[error("{}", render_all(.0))]
    Unresolved(Vec<Diagnostic>),

    #[error("{0}")]
    Generic(String),
}

pub type UnifierResult<T> = Result<T, UnifierError>;
