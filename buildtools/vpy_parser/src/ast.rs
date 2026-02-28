use std::collections::HashMap;

/// Root module containing all items and metadata
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Module {
    pub items: Vec<Item>,
    pub meta: ModuleMeta,
    pub imports: Vec<ImportDecl>,
}

/// Module metadata (title, author, ROM config, etc.)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModuleMeta {
    pub title_override: Option<String>,
    pub metas: HashMap<String, String>,
    /// BIOS copyright-screen music pointer. Defaults to "music1" (BIOS jingle).
    pub music_override: Option<String>,
    pub copyright_override: Option<String>,
    /// Total ROM size in bytes (e.g., 524288 for 512KB multibank)
    pub rom_total_size: Option<u32>,
    /// Bank size in bytes (e.g., 16384 for 16KB)
    pub rom_bank_size: Option<u32>,
    /// Inject VIA T2 catch-up: call AUDIO_UPDATE twice when a frame is slow. Default: true.
    pub music_timer: bool,
}

impl Default for ModuleMeta {
    fn default() -> Self {
        ModuleMeta {
            title_override: None,
            metas: HashMap::new(),
            music_override: Some("music1".to_string()),
            copyright_override: None,
            rom_total_size: None,
            rom_bank_size: None,
            music_timer: true,
        }
    }
}

/// Top-level items in a module
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Item {
    Function(Function),
    Const {
        name: String,
        type_annotation: Option<String>,
        value: Expr,
        source_line: usize,
    },
    GlobalLet {
        name: String,
        type_annotation: Option<String>,
        value: Expr,
        source_line: usize,
    },
    VectorList {
        name: String,
        entries: Vec<VlEntry>,
    },
    ExprStatement(Expr),
    Export(ExportDecl),
    StructDef(StructDef),
}

/// Vector list entries (for VECTORLIST blocks)
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VlEntry {
    Intensity(i32),
    Origin,
    Move(i32, i32),
    Rect(i32, i32, i32, i32),
    Polygon(Vec<(i32, i32)>),
    Circle { cx: i32, cy: i32, r: i32, segs: i32 },
    Arc {
        cx: i32,
        cy: i32,
        r: i32,
        start_deg: i32,
        sweep_deg: i32,
        segs: i32,
    },
    Spiral {
        cx: i32,
        cy: i32,
        r_start: i32,
        r_end: i32,
        turns: i32,
        segs: i32,
    },
}

/// Function definition
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Function {
    pub name: String,
    pub line: usize,
    pub params: Vec<String>,
    pub body: Vec<Stmt>,
}

/// Struct definition with fields and methods
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StructDef {
    pub name: String,
    pub fields: Vec<FieldDef>,
    pub methods: Vec<Function>,
    pub constructor: Option<Function>,
    pub source_line: usize,
}

/// Field in a struct definition
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldDef {
    pub name: String,
    pub type_annotation: Option<String>,
    pub source_line: usize,
}

/// Import declaration
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImportDecl {
    pub module_path: Vec<String>,
    pub symbols: ImportSymbols,
    pub source_line: usize,
    pub is_relative: bool,
    pub relative_level: usize,
}

/// Import symbol variations
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ImportSymbols {
    /// import module [as alias]
    Module { alias: Option<String> },
    /// from module import *
    All,
    /// from module import a, b as c, ...
    Named(Vec<ImportedSymbol>),
}

/// Single imported symbol with optional alias
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImportedSymbol {
    pub name: String,
    pub alias: Option<String>,
}

/// Export declaration
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExportDecl {
    pub symbols: Vec<String>,
    pub source_line: usize,
}

/// Statements
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Stmt {
    Assign {
        target: AssignTarget,
        value: Expr,
        source_line: usize,
    },
    Let {
        name: String,
        type_annotation: Option<String>,
        value: Expr,
        source_line: usize,
    },
    For {
        var: String,
        start: Expr,
        end: Expr,
        step: Option<Expr>,
        body: Vec<Stmt>,
        source_line: usize,
    },
    ForIn {
        var: String,
        iterable: Expr,
        body: Vec<Stmt>,
        source_line: usize,
    },
    While {
        cond: Expr,
        body: Vec<Stmt>,
        source_line: usize,
    },
    Break {
        source_line: usize,
    },
    Continue {
        source_line: usize,
    },
    Pass {
        source_line: usize,
    },
    Expr(Expr, usize),
    If {
        cond: Expr,
        body: Vec<Stmt>,
        elifs: Vec<(Expr, Vec<Stmt>)>,
        else_body: Option<Vec<Stmt>>,
        source_line: usize,
    },
    Switch {
        expr: Expr,
        cases: Vec<(Expr, Vec<Stmt>)>,
        default: Option<Vec<Stmt>>,
        source_line: usize,
    },
    Return(Option<Expr>, usize),
    CompoundAssign {
        target: AssignTarget,
        op: BinOp,
        value: Expr,
        source_line: usize,
    },
}

impl Stmt {
    pub fn source_line(&self) -> usize {
        match self {
            Stmt::Assign { source_line, .. } => *source_line,
            Stmt::Let { source_line, .. } => *source_line,
            Stmt::For { source_line, .. } => *source_line,
            Stmt::ForIn { source_line, .. } => *source_line,
            Stmt::While { source_line, .. } => *source_line,
            Stmt::Break { source_line } => *source_line,
            Stmt::Continue { source_line } => *source_line,
            Stmt::Pass { source_line } => *source_line,
            Stmt::Expr(_, source_line) => *source_line,
            Stmt::If { source_line, .. } => *source_line,
            Stmt::Switch { source_line, .. } => *source_line,
            Stmt::Return(_, source_line) => *source_line,
            Stmt::CompoundAssign { source_line, .. } => *source_line,
        }
    }
}

/// Assignment target (variable, array index, or field)
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AssignTarget {
    Ident {
        name: String,
        source_line: usize,
        col: usize,
    },
    Index {
        target: Box<Expr>,
        index: Box<Expr>,
        source_line: usize,
        col: usize,
    },
    FieldAccess {
        target: Box<Expr>,
        field: String,
        source_line: usize,
        col: usize,
    },
}

/// Expressions
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expr {
    Number(i32),
    StringLit(String),
    Ident(IdentInfo),
    Call(CallInfo),
    MethodCall(MethodCallInfo),
    Binary {
        op: BinOp,
        left: Box<Expr>,
        right: Box<Expr>,
    },
    Compare {
        op: CmpOp,
        left: Box<Expr>,
        right: Box<Expr>,
    },
    Logic {
        op: LogicOp,
        left: Box<Expr>,
        right: Box<Expr>,
    },
    Not(Box<Expr>),
    BitNot(Box<Expr>),
    List(Vec<Expr>),
    Index {
        target: Box<Expr>,
        index: Box<Expr>,
    },
    StructInit {
        struct_name: String,
        source_line: usize,
        col: usize,
    },
    FieldAccess {
        target: Box<Expr>,
        field: String,
        source_line: usize,
        col: usize,
    },
}

/// Identifier information
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IdentInfo {
    pub name: String,
    pub source_line: usize,
    pub col: usize,
}

/// Function call information
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CallInfo {
    pub name: String,
    pub source_line: usize,
    pub col: usize,
    pub args: Vec<Expr>,
}

/// Method call information
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MethodCallInfo {
    pub target: Box<Expr>,
    pub method_name: String,
    pub args: Vec<Expr>,
    pub source_line: usize,
    pub col: usize,
}

/// Binary operators
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    FloorDiv,
    Mod,
    Shl,
    Shr,
    BitAnd,
    BitOr,
    BitXor,
}

/// Comparison operators
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CmpOp {
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
}

/// Logical operators
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogicOp {
    And,
    Or,
}
