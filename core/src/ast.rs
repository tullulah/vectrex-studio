#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Module {
	pub items: Vec<Item>,
	pub meta: ModuleMeta,
	/// Imports declarados en este módulo
	pub imports: Vec<ImportDecl>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModuleMeta {
	pub title_override: Option<String>,
	pub metas: std::collections::HashMap<String,String>,
	/// BIOS copyright-screen music pointer. Defaults to "music1" (BIOS jingle).
	pub music_override: Option<String>,
	pub copyright_override: Option<String>,
	/// Inject VIA T2 catch-up: call AUDIO_UPDATE twice when a frame is slow. Default: true.
	pub music_timer: bool,
	/// Interleaved rendering: split draw calls across N frame groups. None = disabled.
	pub interleaved_frames: Option<u8>,
}

impl Default for ModuleMeta {
	fn default() -> Self {
		ModuleMeta {
			title_override: None,
			metas: std::collections::HashMap::new(),
			music_override: Some("music1".to_string()),
			copyright_override: None,
			music_timer: true,
			interleaved_frames: None,
		}
	}
}

/// Declaración de import
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImportDecl {
	/// Ruta del módulo (ej: ["utils", "math"] para "from utils.math import X")
	pub module_path: Vec<String>,
	/// Símbolos importados
	pub symbols: ImportSymbols,
	/// Línea fuente
	pub source_line: usize,
	/// Es import relativo (empieza con . o ..)
	pub is_relative: bool,
	/// Nivel de relatividad (0 = absoluto, 1 = ., 2 = .., etc)
	pub relative_level: usize,
}

/// Símbolos importados
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ImportSymbols {
	/// import module - importa el módulo completo
	Module { alias: Option<String> },
	/// from module import * - importa todo
	All,
	/// from module import a, b as c - símbolos específicos
	Named(Vec<ImportedSymbol>),
}

/// Un símbolo importado con alias opcional
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImportedSymbol {
	pub name: String,
	pub alias: Option<String>,
}

/// Declaración de export
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExportDecl {
	pub symbols: Vec<String>,
	pub source_line: usize,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Item {
    Function(Function),
    Const { name: String, type_annotation: Option<String>, value: Expr, source_line: usize },
    GlobalLet { name: String, type_annotation: Option<String>, value: Expr, source_line: usize },
    VectorList { name: String, entries: Vec<VlEntry> },
    ExprStatement(Expr),  // Para permitir expresiones ejecutables en top-level
    /// Declaración de export explícita
    Export(ExportDecl),
    /// Definición de struct
    StructDef(StructDef),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VlEntry {
	Intensity(i32),
	Origin,
	Move(i32,i32),
	Rect(i32,i32,i32,i32),
	Polygon(Vec<(i32,i32)>),
	Circle { cx:i32, cy:i32, r:i32, segs:i32 },
	Arc { cx:i32, cy:i32, r:i32, start_deg:i32, sweep_deg:i32, segs:i32 },
	Spiral { cx:i32, cy:i32, r_start:i32, r_end:i32, turns:i32, segs:i32 },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Function {
	pub name: String,
	pub line: usize,  // Starting line number of function definition
	#[allow(dead_code)] pub params: Vec<String>,
	pub body: Vec<Stmt>,
	/// Interleaved frame group this function belongs to (from @frame(N) decorator). None = always runs.
	pub frame_group: Option<u8>,
}

/// Definición de struct
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StructDef {
	pub name: String,
	pub fields: Vec<FieldDef>,
	pub methods: Vec<Function>,
	/// Constructor opcional (__init__)
	pub constructor: Option<Function>,
	pub source_line: usize,
}

/// Campo de un struct
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FieldDef {
	pub name: String,
	pub type_annotation: Option<String>,  // "int", nombre de otro struct, etc.
	pub source_line: usize,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Stmt {
	Assign { target: AssignTarget, value: Expr, source_line: usize },
	Let { name: String, value: Expr, source_line: usize },
	For { var: String, start: Expr, end: Expr, step: Option<Expr>, body: Vec<Stmt>, source_line: usize },
	ForIn { var: String, iterable: Expr, body: Vec<Stmt>, source_line: usize },
	While { cond: Expr, body: Vec<Stmt>, source_line: usize },
	Break { source_line: usize },
	Continue { source_line: usize },
	Pass { source_line: usize },
	Expr(Expr, usize), // (expression, line)
	If { cond: Expr, body: Vec<Stmt>, elifs: Vec<(Expr, Vec<Stmt>)>, else_body: Option<Vec<Stmt>>, source_line: usize },
	Switch { expr: Expr, cases: Vec<(Expr, Vec<Stmt>)>, default: Option<Vec<Stmt>>, source_line: usize },
	Return(Option<Expr>, usize), // (value, line)
	// Operadores de asignación compuesta: var += expr
	CompoundAssign { target: AssignTarget, op: BinOp, value: Expr, source_line: usize },
}

impl Stmt {
	/// Get the source line number for any statement
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IdentInfo { pub name: String, pub source_line: usize, pub col: usize }

// Nuevo: información de asignación con span para el identificador del LHS.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AssignTarget { 
	/// Simple variable: x = value
	Ident { name: String, source_line: usize, col: usize },
	/// Array index: arr[i] = value
	Index { target: Box<Expr>, index: Box<Expr>, source_line: usize, col: usize },
	/// Field access: obj.field = value
	FieldAccess { target: Box<Expr>, field: String, source_line: usize, col: usize },
}

// Información de llamadas con span del identificador (primer segmento calificado).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CallInfo { pub name: String, pub source_line: usize, pub col: usize, pub args: Vec<Expr> }

// Información de llamadas a métodos: obj.method(args)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MethodCallInfo {
    pub target: Box<Expr>,  // obj expression (could be self, variable, or field access)
    pub method_name: String,
    pub args: Vec<Expr>,
    pub source_line: usize,
    pub col: usize,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expr {
	Number(i32),
	StringLit(String),
	Ident(IdentInfo),
	Call(CallInfo),
	MethodCall(MethodCallInfo),
	Binary { op: BinOp, left: Box<Expr>, right: Box<Expr> },
	Compare { op: CmpOp, left: Box<Expr>, right: Box<Expr> },
	Logic { op: LogicOp, left: Box<Expr>, right: Box<Expr> },
	Not(Box<Expr>),
	BitNot(Box<Expr>),
	/// Array literal: [1, 2, 3]
	List(Vec<Expr>),
	/// Array indexing: arr[i]
	Index { target: Box<Expr>, index: Box<Expr> },
	/// Struct initialization: Point()
	StructInit { struct_name: String, source_line: usize, col: usize },
	/// Field access: obj.field
	FieldAccess { target: Box<Expr>, field: String, source_line: usize, col: usize },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinOp { Add, Sub, Mul, Div, FloorDiv, Mod, Shl, Shr, BitAnd, BitOr, BitXor }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CmpOp { Eq, Ne, Lt, Le, Gt, Ge }

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogicOp { And, Or }
