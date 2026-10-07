//! VPy Unifier: Phase 3 of buildtools compiler pipeline
//!
//! Resolves imports, validates symbols, and merges multiple modules into one
//!
//! # Module Structure
//!
//! - `error.rs`: Error types (UnifierError, UnifierResult, Diagnostic)
//! - `graph.rs`: Module dependency graph with cycle detection
//! - `resolver.rs`: Symbol resolver for unified naming
//! - `visitor.rs`: AST visitor pattern for custom passes
//! - `scope.rs`: Scope management (variables, functions, imports)
//!
//! # Input
//! `Vec<Module>` (parsed AST from Phase 2)
//!
//! # Output
//! `Module` (single merged module with resolved imports)
//!
//! # Phases
//!
//! 1. **Load & Graph**: one node per module, one edge per `import`
//! 2. **Import check**: every imported module (and `from m import s` symbol) exists
//! 3. **Cycle Detection** + **Topological Sort** (dependencies first, deterministic)
//! 4. **Resolve + rename**: every top-level symbol of an imported module becomes
//!    `MODULE_symbol` ([`vpy_parser::symbols::mangle`]); every reference to it —
//!    `module.f()`, `module.var`, `module.arr[i]`, `module.var = …`, a bare name
//!    inside the module itself, a `from module import name` — is rewritten to
//!    the SAME string. Entry-module symbols are upper-cased (no prefix).
//! 5. **Validation**: a `module.symbol` that does not resolve is an error with
//!    the module and line, never a silent pass-through.

pub mod error;
pub mod graph;
pub mod resolver;
pub mod scope;
pub mod type_tracker;
pub mod types;
pub mod visitor;

pub use error::{Diagnostic, UnifierError, UnifierResult};
pub use graph::ModuleGraph;
pub use resolver::SymbolResolver;
pub use scope::Scope;
pub use type_tracker::TypeTracker;
pub use types::VarType;
pub use visitor::AstVisitor;
pub use vpy_parser::ast::{Module, Item, ImportDecl};

use std::collections::{BTreeMap, HashMap, HashSet};
use vpy_parser::ast::{AssignTarget, CallInfo, Expr, IdentInfo, ImportSymbols, MethodCallInfo, Stmt};
use vpy_parser::symbols;

/// What a top-level symbol is (used for error messages and `module.x` checks).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SymKind {
    Function,
    Global,
    Const,
}

impl SymKind {
    fn describe(self) -> &'static str {
        match self {
            SymKind::Function => "function",
            SymKind::Global => "variable",
            SymKind::Const => "const",
        }
    }
}

/// Top-level symbols of one module, keyed by lower-case name (identifiers are
/// case-insensitive); the value keeps the spelling of the definition.
#[derive(Debug, Default)]
struct ModuleSymbols {
    defs: HashMap<String, (String, SymKind)>,
}

impl ModuleSymbols {
    fn of(module: &Module) -> Self {
        let mut defs = HashMap::new();
        for item in &module.items {
            let (name, kind) = match item {
                Item::Function(f) => (&f.name, SymKind::Function),
                Item::GlobalLet { name, .. } => (name, SymKind::Global),
                Item::Const { name, .. } => (name, SymKind::Const),
                _ => continue,
            };
            // First definition wins (a later re-declaration keeps the same symbol).
            defs.entry(name.to_lowercase()).or_insert_with(|| (name.clone(), kind));
        }
        ModuleSymbols { defs }
    }

    fn get(&self, name: &str) -> Option<&(String, SymKind)> {
        self.defs.get(&name.to_lowercase())
    }

    fn listing(&self) -> String {
        let mut names: Vec<&str> = self.defs.values().map(|(n, _)| n.as_str()).collect();
        names.sort_unstable();
        names.join(", ")
    }
}

/// Unify multiple modules into a single resolved module
///
/// # Arguments
/// * `modules` - Map of module names (file stems) to parsed Modules from Phase 2
/// * `entry_module` - Name of the entry module (its symbols get no prefix)
///
/// # Returns
/// * `UnifierResult<Module>` - Unified module, or every resolution error found
pub fn unify_modules(
    modules: HashMap<String, Module>,
    entry_module: &str,
) -> UnifierResult<Module> {
    // Symbol tables first (resolution needs every module's definitions).
    let tables: HashMap<String, ModuleSymbols> = modules
        .iter()
        .map(|(name, m)| (name.clone(), ModuleSymbols::of(m)))
        .collect();

    let mut diags: Vec<Diagnostic> = Vec::new();

    // Phase 3.1: Build graph (nodes + one edge per import)
    let mut graph = ModuleGraph::new();
    let mut names: Vec<&String> = modules.keys().collect();
    names.sort();
    for name in &names {
        graph.add_module((*name).clone(), modules[*name].clone());
    }
    for name in &names {
        for import in &modules[*name].imports {
            if let Some(target) = find_module(&modules, import_module_name(import)) {
                if target != **name {
                    graph.add_dependency((*name).clone(), target)?;
                }
            }
        }
    }

    // Phase 3.2: Every import must name a compiled module.
    for name in &names {
        check_imports(name, &modules[*name], &modules, &tables, &mut diags);
    }

    // Phase 3.3: Detect cycles + topological sort
    if let Some(cycle) = graph.detect_cycles() {
        return Err(UnifierError::CircularDependency(cycle.join(" -> ")));
    }
    let sort_order = graph.topological_sort()?;

    // Phase 3.4: Resolve + rename, module by module
    let mut merged_items = Vec::new();
    let mut merged_meta = Default::default();
    for module_name in &sort_order {
        let Some(module) = graph.get_module(module_name) else { continue };
        if module_name == entry_module {
            merged_meta = module.meta.clone();
        }
        let mut ctx = Ctx::new(module_name, entry_module, module, &modules, &tables);
        for item in &module.items {
            merged_items.push(ctx.rewrite_item(item));
        }
        diags.append(&mut ctx.diags);
    }

    // Phase 3.5: Two modules must not produce the same assembly-level name
    // (labels are case-insensitive downstream: VAR_<NAME>, m6809 labels).
    check_collisions(&sort_order, &modules, entry_module, &mut diags);

    if !diags.is_empty() {
        return Err(UnifierError::Unresolved(diags));
    }

    Ok(Module {
        items: merged_items,
        meta: merged_meta,
        imports: vec![], // All imports resolved, empty in unified module
    })
}

/// Unified name of `def` (spelled as defined) living in `module`.
fn canonical(module: &str, entry: &str, def: &str) -> String {
    if module == entry {
        symbols::entry_symbol(def)
    } else {
        symbols::mangle(module, def)
    }
}

/// Module name an import refers to (`import a` / `from a import x` → `a`).
fn import_module_name(import: &ImportDecl) -> &str {
    import.module_path.last().map(|s| s.as_str()).unwrap_or("")
}

/// Find a compiled module by name: exact match first, then case-insensitive.
fn find_module(modules: &HashMap<String, Module>, name: &str) -> Option<String> {
    if modules.contains_key(name) {
        return Some(name.to_string());
    }
    let lower = name.to_lowercase();
    let mut hits: Vec<&String> = modules.keys().filter(|k| k.to_lowercase() == lower).collect();
    hits.sort();
    hits.first().map(|s| (*s).clone())
}

fn known_modules(modules: &HashMap<String, Module>) -> String {
    let mut names: Vec<&str> = modules.keys().map(|s| s.as_str()).collect();
    names.sort_unstable();
    names.join(", ")
}

fn check_imports(
    module_name: &str,
    module: &Module,
    modules: &HashMap<String, Module>,
    tables: &HashMap<String, ModuleSymbols>,
    diags: &mut Vec<Diagnostic>,
) {
    for import in &module.imports {
        let wanted = import_module_name(import);
        let Some(target) = find_module(modules, wanted) else {
            diags.push(Diagnostic {
                module: module_name.to_string(),
                line: import.source_line,
                message: format!(
                    "module `{wanted}` not found: there is no `{wanted}.vpy` among the compiled sources ({}). \
                     Build the project (.vpyproj) so every file in its [sources] is compiled — a single-file \
                     build only sees that one file — or fix the module name.",
                    known_modules(modules)
                ),
            });
            continue;
        };
        if let ImportSymbols::Named(list) = &import.symbols {
            let table = &tables[&target];
            for sym in list {
                if table.get(&sym.name).is_none() {
                    diags.push(Diagnostic {
                        module: module_name.to_string(),
                        line: import.source_line,
                        message: format!(
                            "cannot import `{}` from module `{target}`: it defines no such function, variable or const (it defines: {})",
                            sym.name,
                            table.listing()
                        ),
                    });
                }
            }
        }
    }
}

fn check_collisions(
    order: &[String],
    modules: &HashMap<String, Module>,
    entry: &str,
    diags: &mut Vec<Diagnostic>,
) {
    let mut seen: HashMap<String, (String, String)> = HashMap::new(); // UPPER → (module, unified)
    for module_name in order {
        let Some(module) = modules.get(module_name) else { continue };
        for item in &module.items {
            let (name, line) = match item {
                Item::Function(f) => (&f.name, f.line),
                Item::GlobalLet { name, source_line, .. } | Item::Const { name, source_line, .. } => (name, *source_line),
                _ => continue,
            };
            let unified = canonical(module_name, entry, name);
            let key = unified.to_uppercase();
            match seen.get(&key) {
                Some((other_module, other_unified)) if other_module != module_name => {
                    diags.push(Diagnostic {
                        module: module_name.clone(),
                        line,
                        message: format!(
                            "`{name}` becomes `{unified}`, which clashes with `{other_unified}` from module `{other_module}` \
                             (assembly labels are case-insensitive) — rename one of them"
                        ),
                    });
                }
                Some(_) => {}
                None => {
                    seen.insert(key, (module_name.clone(), unified));
                }
            }
        }
    }
}

/// Per-module resolution context.
struct Ctx<'a> {
    module: &'a str,
    entry: &'a str,
    modules: &'a HashMap<String, Module>,
    tables: &'a HashMap<String, ModuleSymbols>,
    /// lower-case name usable as `name.x` → module it refers to (`import m [as a]`)
    module_aliases: HashMap<String, String>,
    /// lower-case local name → (module, definition spelling) for `from m import s [as a]`
    named: HashMap<String, (String, String)>,
    /// lower-case names of imported modules whose file is missing (already reported)
    missing: HashSet<String>,
    /// lower-case parameter names of the function being rewritten
    params: HashSet<String>,
    diags: Vec<Diagnostic>,
}

impl<'a> Ctx<'a> {
    fn new(
        module: &'a str,
        entry: &'a str,
        m: &Module,
        modules: &'a HashMap<String, Module>,
        tables: &'a HashMap<String, ModuleSymbols>,
    ) -> Self {
        let mut module_aliases = HashMap::new();
        let mut named = HashMap::new();
        let mut missing = HashSet::new();
        for import in &m.imports {
            let wanted = import_module_name(import);
            let Some(target) = find_module(modules, wanted) else {
                let local = match &import.symbols {
                    ImportSymbols::Module { alias: Some(a) } => a.clone(),
                    _ => wanted.to_string(),
                };
                missing.insert(local.to_lowercase());
                continue;
            };
            match &import.symbols {
                ImportSymbols::Module { alias } => {
                    let local = alias.clone().unwrap_or_else(|| wanted.to_string());
                    module_aliases.insert(local.to_lowercase(), target);
                }
                ImportSymbols::All => {
                    for (lower, (def, _)) in &tables[&target].defs {
                        named.insert(lower.clone(), (target.clone(), def.clone()));
                    }
                }
                ImportSymbols::Named(list) => {
                    for sym in list {
                        if let Some((def, _)) = tables[&target].get(&sym.name) {
                            let local = sym.alias.clone().unwrap_or_else(|| sym.name.clone());
                            named.insert(local.to_lowercase(), (target.clone(), def.clone()));
                        }
                    }
                }
            }
        }
        Ctx {
            module,
            entry,
            modules,
            tables,
            module_aliases,
            named,
            missing,
            params: HashSet::new(),
            diags: Vec::new(),
        }
    }

    fn error(&mut self, line: usize, message: String) {
        self.diags.push(Diagnostic { module: self.module.to_string(), line, message });
    }

    fn is_param(&self, name: &str) -> bool {
        self.params.contains(&name.to_lowercase())
    }

    /// Resolve a bare top-level name: own module first, then `from … import`.
    fn resolve_bare(&self, name: &str) -> Option<(String, SymKind)> {
        if self.is_param(name) {
            return None;
        }
        if let Some((def, kind)) = self.tables[self.module].get(name) {
            return Some((canonical(self.module, self.entry, def), *kind));
        }
        if let Some((m, def)) = self.named.get(&name.to_lowercase()) {
            let kind = self.tables[m].get(def).map(|(_, k)| *k).unwrap_or(SymKind::Global);
            return Some((canonical(m, self.entry, def), kind));
        }
        None
    }

    /// Unified name for an identifier used as a value / call target.
    fn ident_name(&self, name: &str) -> String {
        match self.resolve_bare(name) {
            Some((unified, _)) => unified,
            // locals, params, builtins: upper-case, as the backends expect
            None => name.to_uppercase(),
        }
    }

    /// Unified name for a name that DECLARES a local (`for v in`, `let v`).
    /// Kept as written unless it is a module-level symbol of an imported module.
    fn local_decl_name(&self, name: &str) -> String {
        if self.module == self.entry {
            return name.to_string();
        }
        match self.resolve_bare(name) {
            Some((unified, _)) => unified,
            None => name.to_string(),
        }
    }

    /// If `name` (the `x` of `x.y`) denotes a module, return it.
    /// `Err(())` = an imported module whose file is missing (already reported).
    fn module_ref(&mut self, name: &str, line: usize) -> Option<Result<String, ()>> {
        if self.is_param(name) || self.tables[self.module].get(name).is_some()
            || self.named.contains_key(&name.to_lowercase())
        {
            return None; // a value shadows any module of the same name
        }
        let lower = name.to_lowercase();
        if let Some(m) = self.module_aliases.get(&lower) {
            return Some(Ok(m.clone()));
        }
        if self.missing.contains(&lower) {
            return Some(Err(()));
        }
        if let Some(m) = find_module(self.modules, name) {
            if m != self.module {
                self.error(line, format!(
                    "`{name}` is a module, but `{}` does not import it — add `import {m}` at the top of the file",
                    self.module
                ));
                return Some(Err(()));
            }
        }
        None
    }

    /// Resolve `module.symbol`; reports an error and returns `None` if missing.
    fn resolve_member(&mut self, module: &str, symbol: &str, line: usize) -> Option<(String, SymKind)> {
        match self.tables[module].get(symbol) {
            Some((def, kind)) => Some((canonical(module, self.entry, def), *kind)),
            None => {
                let listing = self.tables[module].listing();
                self.error(line, format!(
                    "module `{module}` has no function, variable or const named `{symbol}` (it defines: {listing})"
                ));
                None
            }
        }
    }

    fn rewrite_item(&mut self, item: &Item) -> Item {
        match item {
            Item::Function(func) => {
                let mut new_func = func.clone();
                new_func.name = canonical(self.module, self.entry, &func.name);
                self.params = func.params.iter().map(|p| p.to_lowercase()).collect();
                new_func.body = func.body.iter().map(|s| self.rewrite_stmt(s)).collect();
                self.params.clear();
                Item::Function(new_func)
            }
            Item::GlobalLet { name, type_annotation, value, source_line } => Item::GlobalLet {
                name: canonical(self.module, self.entry, name),
                type_annotation: type_annotation.clone(),
                value: self.rewrite_expr(value),
                source_line: *source_line,
            },
            Item::Const { name, type_annotation, value, source_line } => Item::Const {
                name: canonical(self.module, self.entry, name),
                type_annotation: type_annotation.clone(),
                value: self.rewrite_expr(value),
                source_line: *source_line,
            },
            other => other.clone(),
        }
    }

    fn rewrite_block(&mut self, body: &[Stmt]) -> Vec<Stmt> {
        body.iter().map(|s| self.rewrite_stmt(s)).collect()
    }

    fn rewrite_stmt(&mut self, stmt: &Stmt) -> Stmt {
        match stmt {
            Stmt::Assign { target, value, source_line } => Stmt::Assign {
                target: self.rewrite_target(target),
                value: self.rewrite_expr(value),
                source_line: *source_line,
            },
            Stmt::CompoundAssign { target, op, value, source_line } => Stmt::CompoundAssign {
                target: self.rewrite_target(target),
                op: *op,
                value: self.rewrite_expr(value),
                source_line: *source_line,
            },
            Stmt::Let { name, type_annotation, value, source_line } => Stmt::Let {
                name: self.local_decl_name(name),
                type_annotation: type_annotation.clone(),
                value: self.rewrite_expr(value),
                source_line: *source_line,
            },
            Stmt::If { cond, body, elifs, else_body, source_line } => Stmt::If {
                cond: self.rewrite_expr(cond),
                body: self.rewrite_block(body),
                elifs: elifs.iter().map(|(c, b)| (self.rewrite_expr(c), self.rewrite_block(b))).collect(),
                else_body: else_body.as_ref().map(|b| self.rewrite_block(b)),
                source_line: *source_line,
            },
            Stmt::While { cond, body, source_line } => Stmt::While {
                cond: self.rewrite_expr(cond),
                body: self.rewrite_block(body),
                source_line: *source_line,
            },
            Stmt::For { var, start, end, step, body, source_line } => Stmt::For {
                var: self.local_decl_name(var),
                start: self.rewrite_expr(start),
                end: self.rewrite_expr(end),
                step: step.as_ref().map(|s| self.rewrite_expr(s)),
                body: self.rewrite_block(body),
                source_line: *source_line,
            },
            Stmt::ForIn { var, iterable, body, source_line } => Stmt::ForIn {
                var: self.local_decl_name(var),
                iterable: self.rewrite_expr(iterable),
                body: self.rewrite_block(body),
                source_line: *source_line,
            },
            Stmt::Switch { expr, cases, default, source_line } => Stmt::Switch {
                expr: self.rewrite_expr(expr),
                cases: cases.iter().map(|(e, b)| (self.rewrite_expr(e), self.rewrite_block(b))).collect(),
                default: default.as_ref().map(|b| self.rewrite_block(b)),
                source_line: *source_line,
            },
            Stmt::Return(value, line) => Stmt::Return(value.as_ref().map(|v| self.rewrite_expr(v)), *line),
            Stmt::Expr(expr, line) => Stmt::Expr(self.rewrite_expr(expr), *line),
            Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => stmt.clone(),
        }
    }

    fn rewrite_target(&mut self, target: &AssignTarget) -> AssignTarget {
        match target {
            AssignTarget::Ident { name, source_line, col } => AssignTarget::Ident {
                name: self.ident_name(name),
                source_line: *source_line,
                col: *col,
            },
            AssignTarget::Index { target, index, source_line, col } => AssignTarget::Index {
                target: Box::new(self.rewrite_expr(target)),
                index: Box::new(self.rewrite_expr(index)),
                source_line: *source_line,
                col: *col,
            },
            AssignTarget::FieldAccess { target, field, source_line, col } => {
                if let Expr::Ident(ident) = target.as_ref() {
                    match self.module_ref(&ident.name, *source_line) {
                        Some(Ok(m)) => {
                            let name = match self.resolve_member(&m, field, *source_line) {
                                Some((unified, SymKind::Global)) => unified,
                                Some((unified, kind)) => {
                                    self.error(*source_line, format!(
                                        "cannot assign to `{}.{field}`: it is a {}", ident.name, kind.describe()
                                    ));
                                    unified
                                }
                                None => symbols::mangle(&m, field),
                            };
                            return AssignTarget::Ident { name, source_line: *source_line, col: *col };
                        }
                        Some(Err(())) => {
                            return AssignTarget::Ident {
                                name: symbols::mangle(&ident.name, field),
                                source_line: *source_line,
                                col: *col,
                            };
                        }
                        None => {}
                    }
                }
                AssignTarget::FieldAccess {
                    target: Box::new(self.rewrite_expr(target)),
                    field: field.clone(),
                    source_line: *source_line,
                    col: *col,
                }
            }
        }
    }

    fn rewrite_expr(&mut self, expr: &Expr) -> Expr {
        match expr {
            Expr::Ident(ident) => Expr::Ident(IdentInfo {
                name: self.ident_name(&ident.name),
                source_line: ident.source_line,
                col: ident.col,
            }),

            Expr::Call(call) => Expr::Call(CallInfo {
                name: self.ident_name(&call.name),
                args: call.args.iter().map(|a| self.rewrite_expr(a)).collect(),
                source_line: call.source_line,
                col: call.col,
            }),

            // module.function(args) → Call(MODULE_function)
            Expr::MethodCall(call) => {
                let args: Vec<Expr> = call.args.iter().map(|a| self.rewrite_expr(a)).collect();
                if let Expr::Ident(ident) = call.target.as_ref() {
                    match self.module_ref(&ident.name, call.source_line) {
                        Some(Ok(m)) => {
                            let name = match self.resolve_member(&m, &call.method_name, call.source_line) {
                                Some((unified, SymKind::Function)) => unified,
                                Some((unified, kind)) => {
                                    self.error(call.source_line, format!(
                                        "`{}.{}` is a {}, not a function — drop the parentheses",
                                        ident.name, call.method_name, kind.describe()
                                    ));
                                    unified
                                }
                                None => symbols::mangle(&m, &call.method_name),
                            };
                            return Expr::Call(CallInfo { name, args, source_line: call.source_line, col: call.col });
                        }
                        Some(Err(())) => {
                            return Expr::Call(CallInfo {
                                name: symbols::mangle(&ident.name, &call.method_name),
                                args,
                                source_line: call.source_line,
                                col: call.col,
                            });
                        }
                        None => {}
                    }
                }
                // A method on a value (`x.abs()`, `x.clamp(lo, hi)`): the backend handles it.
                Expr::MethodCall(MethodCallInfo {
                    target: Box::new(self.rewrite_expr(&call.target)),
                    method_name: call.method_name.clone(),
                    args,
                    source_line: call.source_line,
                    col: call.col,
                })
            }

            // module.symbol → Ident(MODULE_symbol)
            Expr::FieldAccess { target, field, source_line, col } => {
                if let Expr::Ident(ident) = target.as_ref() {
                    match self.module_ref(&ident.name, *source_line) {
                        Some(Ok(m)) => {
                            let name = match self.resolve_member(&m, field, *source_line) {
                                Some((unified, SymKind::Function)) => {
                                    self.error(*source_line, format!(
                                        "`{}.{field}` is a function — call it: `{}.{field}(...)`", ident.name, ident.name
                                    ));
                                    unified
                                }
                                Some((unified, _)) => unified,
                                None => symbols::mangle(&m, field),
                            };
                            return Expr::Ident(IdentInfo { name, source_line: *source_line, col: *col });
                        }
                        Some(Err(())) => {
                            return Expr::Ident(IdentInfo {
                                name: symbols::mangle(&ident.name, field),
                                source_line: *source_line,
                                col: *col,
                            });
                        }
                        None => {}
                    }
                }
                Expr::FieldAccess {
                    target: Box::new(self.rewrite_expr(target)),
                    field: field.clone(),
                    source_line: *source_line,
                    col: *col,
                }
            }

            Expr::Binary { op, left, right } => Expr::Binary {
                op: *op,
                left: Box::new(self.rewrite_expr(left)),
                right: Box::new(self.rewrite_expr(right)),
            },
            Expr::Compare { op, left, right } => Expr::Compare {
                op: *op,
                left: Box::new(self.rewrite_expr(left)),
                right: Box::new(self.rewrite_expr(right)),
            },
            Expr::Logic { op, left, right } => Expr::Logic {
                op: *op,
                left: Box::new(self.rewrite_expr(left)),
                right: Box::new(self.rewrite_expr(right)),
            },
            Expr::Not(e) => Expr::Not(Box::new(self.rewrite_expr(e))),
            Expr::BitNot(e) => Expr::BitNot(Box::new(self.rewrite_expr(e))),
            Expr::List(elements) => Expr::List(elements.iter().map(|e| self.rewrite_expr(e)).collect()),
            Expr::Index { target, index } => Expr::Index {
                target: Box::new(self.rewrite_expr(target)),
                index: Box::new(self.rewrite_expr(index)),
            },

            // Literals and struct constructors: nothing to resolve
            Expr::Number(_) | Expr::StringLit(_) | Expr::StructInit { .. } => expr.clone(),
        }
    }
}

/// Symbols the unified module defines, unified name → kind description.
/// Handy for tests and tools that want to inspect the result of Phase 3.
pub fn defined_symbols(unified: &Module) -> BTreeMap<String, &'static str> {
    unified
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some((f.name.clone(), SymKind::Function.describe())),
            Item::GlobalLet { name, .. } => Some((name.clone(), SymKind::Global.describe())),
            Item::Const { name, .. } => Some((name.clone(), SymKind::Const.describe())),
            _ => None,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    use vpy_parser::ast::ModuleMeta;

    #[test]
    fn test_unify_single_module() {
        let mut modules = HashMap::new();
        let module = Module {
            items: vec![],
            meta: ModuleMeta::default(),
            imports: vec![],
        };
        modules.insert("main".to_string(), module);

        let result = unify_modules(modules, "main");
        assert!(result.is_ok());
        let unified = result.unwrap();
        assert_eq!(unified.items.len(), 0);
    }

    #[test]
    fn test_unify_no_circular_import() {
        let mut modules = HashMap::new();
        let module = Module {
            items: vec![],
            meta: ModuleMeta::default(),
            imports: vec![],
        };
        modules.insert("main".to_string(), module.clone());
        modules.insert("util".to_string(), module);

        let result = unify_modules(modules, "main");
        assert!(result.is_ok());
    }

    #[test]
    fn test_symbol_resolver_basic() {
        let mut resolver = SymbolResolver::new();

        resolver.register_module("main");
        resolver.register_module("input");

        assert_eq!(resolver.resolve_symbol("func", "main"), "func");
        assert_eq!(resolver.resolve_symbol("func", "input"), "INPUT_func");
    }

    #[test]
    fn test_graph_creation() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        graph.add_module("test".to_string(), module);
        assert_eq!(graph.modules().len(), 1);
    }

    #[test]
    fn test_cycle_detection() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        graph.add_module("a".to_string(), module.clone());
        graph.add_module("b".to_string(), module);

        graph.add_dependency("a".to_string(), "b".to_string()).unwrap();
        graph.add_dependency("b".to_string(), "a".to_string()).unwrap();

        assert!(graph.detect_cycles().is_some());
    }

    #[test]
    fn test_topological_sort() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: ModuleMeta::default(),
            imports: vec![],
        };

        graph.add_module("util".to_string(), module.clone());
        graph.add_module("input".to_string(), module.clone());
        graph.add_module("main".to_string(), module);

        graph.add_dependency("input".to_string(), "util".to_string()).unwrap();
        graph.add_dependency("main".to_string(), "input".to_string()).unwrap();

        let order = graph.topological_sort().unwrap();

        // Check correct order
        assert_eq!(order.len(), 3);
        let util_idx = order.iter().position(|x| x == "util").unwrap();
        let input_idx = order.iter().position(|x| x == "input").unwrap();
        let main_idx = order.iter().position(|x| x == "main").unwrap();

        assert!(util_idx < input_idx);
        assert!(input_idx < main_idx);
    }

    // ---- Cross-module resolution (regression: definition and reference must agree) ----

    fn parse(src: &str, file: &str) -> Module {
        let tokens = vpy_parser::lex(src).expect("lex");
        vpy_parser::parser::parse(tokens, file).expect("parse")
    }

    fn unify(srcs: &[(&str, &str)]) -> UnifierResult<Module> {
        let mut modules = HashMap::new();
        for (name, src) in srcs {
            modules.insert(name.to_string(), parse(src, &format!("{name}.vpy")));
        }
        unify_modules(modules, "main")
    }

    /// Every Call / Ident name in the unified module, in order.
    fn references(m: &Module) -> Vec<String> {
        fn expr(e: &Expr, out: &mut Vec<String>) {
            match e {
                Expr::Ident(i) => out.push(i.name.clone()),
                Expr::Call(c) => {
                    out.push(c.name.clone());
                    c.args.iter().for_each(|a| expr(a, out));
                }
                Expr::MethodCall(c) => {
                    expr(&c.target, out);
                    c.args.iter().for_each(|a| expr(a, out));
                }
                Expr::Binary { left, right, .. } | Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => {
                    expr(left, out);
                    expr(right, out);
                }
                Expr::Not(e) | Expr::BitNot(e) => expr(e, out),
                Expr::List(l) => l.iter().for_each(|x| expr(x, out)),
                Expr::Index { target, index } => {
                    expr(target, out);
                    expr(index, out);
                }
                Expr::FieldAccess { target, .. } => expr(target, out),
                _ => {}
            }
        }
        fn stmt(s: &Stmt, out: &mut Vec<String>) {
            match s {
                Stmt::Assign { target, value, .. } | Stmt::CompoundAssign { target, value, .. } => {
                    match target {
                        AssignTarget::Ident { name, .. } => out.push(name.clone()),
                        AssignTarget::Index { target, index, .. } => {
                            expr(target, out);
                            expr(index, out);
                        }
                        AssignTarget::FieldAccess { target, .. } => expr(target, out),
                    }
                    expr(value, out);
                }
                Stmt::Expr(e, _) | Stmt::Return(Some(e), _) => expr(e, out),
                Stmt::If { cond, body, elifs, else_body, .. } => {
                    expr(cond, out);
                    body.iter().for_each(|s| stmt(s, out));
                    for (c, b) in elifs {
                        expr(c, out);
                        b.iter().for_each(|s| stmt(s, out));
                    }
                    if let Some(b) = else_body {
                        b.iter().for_each(|s| stmt(s, out));
                    }
                }
                Stmt::While { cond, body, .. } => {
                    expr(cond, out);
                    body.iter().for_each(|s| stmt(s, out));
                }
                Stmt::For { var, start, end, body, .. } => {
                    out.push(var.clone());
                    expr(start, out);
                    expr(end, out);
                    body.iter().for_each(|s| stmt(s, out));
                }
                _ => {}
            }
        }
        let mut out = Vec::new();
        for item in &m.items {
            if let Item::Function(f) = item {
                f.body.iter().for_each(|s| stmt(s, &mut out));
            }
        }
        out
    }

    const PHYSICS: &str = "\
const MAX_X = 100
speed = 3
table = [1, 2, 3]

def clamp_x(v):
    if v > MAX_X:
        return MAX_X
    for i in range(0, 2):
        speed += table[i]
    return v + speed

def Step(v):
    speed = speed + 1
    return clamp_x(v) + table[1]
";

    #[test]
    fn module_function_call_matches_definition() {
        let main = "import physics\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    x = physics.clamp_x(5)\n";
        let unified = unify(&[("main", main), ("physics", PHYSICS)]).expect("unify");
        let defs = defined_symbols(&unified);
        assert!(defs.contains_key("PHYSICS_clamp_x"), "defs: {defs:?}");
        assert!(defs.contains_key("PHYSICS_Step"));
        assert!(defs.contains_key("PHYSICS_speed"));
        assert!(defs.contains_key("PHYSICS_MAX_X"));
        assert!(defs.contains_key("PHYSICS_table"));
        assert!(defs.contains_key("MAIN") && defs.contains_key("LOOP"));
        let refs = references(&unified);
        assert!(refs.contains(&"PHYSICS_clamp_x".to_string()), "refs: {refs:?}");
        // every reference to a module symbol must be spelled exactly like a definition
        for r in refs.iter().filter(|r| r.starts_with("PHYSICS_")) {
            assert!(defs.contains_key(r), "reference `{r}` has no matching definition; defs: {defs:?}");
        }
    }

    #[test]
    fn module_internal_references_are_prefixed() {
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.Step(1)\n";
        let unified = unify(&[("main", main), ("physics", PHYSICS)]).expect("unify");
        let refs = references(&unified);
        // inside physics: MAX_X, speed, table and clamp_x are the module's own symbols
        for want in ["PHYSICS_MAX_X", "PHYSICS_speed", "PHYSICS_table", "PHYSICS_clamp_x"] {
            assert!(refs.contains(&want.to_string()), "missing {want} in {refs:?}");
        }
        // parameters and locals are not module symbols
        assert!(refs.contains(&"V".to_string()));
        assert!(!refs.iter().any(|r| r == "PHYSICS_v" || r == "PHYSICS_i"));
        assert!(!refs.iter().any(|r| r == "SPEED" || r == "TABLE" || r == "MAX_X" || r == "CLAMP_X"),
            "an unprefixed module symbol leaked: {refs:?}");
    }

    #[test]
    fn module_globals_consts_arrays_from_entry() {
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    physics.speed = 2\n    x = physics.MAX_X + physics.table[0]\n    physics.table[1] = x\n";
        let unified = unify(&[("main", main), ("physics", PHYSICS)]).expect("unify");
        let refs = references(&unified);
        for want in ["PHYSICS_speed", "PHYSICS_MAX_X", "PHYSICS_table"] {
            assert!(refs.contains(&want.to_string()), "missing {want} in {refs:?}");
        }
    }

    #[test]
    fn case_variants_resolve_to_the_definition() {
        let main = "import Physics\n\ndef main():\n    pass\n\ndef loop():\n    a = physics.CLAMP_X(1)\n    b = PHYSICS.clamp_x(2)\n    c = physics.step(3)\n    d = physics.max_x\n";
        let unified = unify(&[("main", main), ("physics", PHYSICS)]).expect("unify");
        let refs = references(&unified);
        // 2 calls from main (CLAMP_X, PHYSICS.clamp_x) + 1 from physics.Step itself
        assert_eq!(refs.iter().filter(|r| *r == "PHYSICS_clamp_x").count(), 3, "{refs:?}");
        assert!(refs.contains(&"PHYSICS_Step".to_string()));
        assert!(refs.contains(&"PHYSICS_MAX_X".to_string()));
    }

    #[test]
    fn import_alias_and_from_import() {
        let main = "import physics as ph\nfrom physics import clamp_x, speed as spd\n\ndef main():\n    pass\n\ndef loop():\n    a = ph.clamp_x(1)\n    b = clamp_x(2) + spd\n";
        let unified = unify(&[("main", main), ("physics", PHYSICS)]).expect("unify");
        let refs = references(&unified);
        // ph.clamp_x + bare clamp_x from main, + 1 from physics.Step itself
        assert_eq!(refs.iter().filter(|r| *r == "PHYSICS_clamp_x").count(), 3, "{refs:?}");
        assert!(refs.contains(&"PHYSICS_speed".to_string()));
    }

    #[test]
    fn module_importing_module_orders_dependencies_first() {
        let util = "def twice(v):\n    return v + v\n";
        let physics = "import util\n\ndef go(v):\n    return util.twice(v)\n";
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.go(1)\n";
        let unified = unify(&[("main", main), ("physics", physics), ("util", util)]).expect("unify");
        let names: Vec<String> = defined_symbols(&unified).into_keys().collect();
        assert!(names.contains(&"UTIL_twice".to_string()));
        assert!(references(&unified).contains(&"UTIL_twice".to_string()));
        let pos = |n: &str| unified.items.iter().position(|i| matches!(i, Item::Function(f) if f.name == n)).unwrap();
        assert!(pos("UTIL_twice") < pos("PHYSICS_go") && pos("PHYSICS_go") < pos("MAIN"));
    }

    #[test]
    fn entry_module_names_are_unchanged() {
        // single-module programs keep the long-standing upper-case canonical names
        let main = "px = 0\n\ndef helper(v):\n    return v\n\ndef main():\n    pass\n\ndef loop():\n    px = helper(px)\n    DRAW_LINE(0, 0, px, 0, 127)\n";
        let unified = unify(&[("main", main)]).expect("unify");
        let defs = defined_symbols(&unified);
        assert!(defs.contains_key("PX") && defs.contains_key("HELPER"));
        let refs = references(&unified);
        assert!(refs.contains(&"HELPER".to_string()) && refs.contains(&"PX".to_string()) && refs.contains(&"DRAW_LINE".to_string()));
    }

    #[test]
    fn entry_module_need_not_be_called_main() {
        let game = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.clamp_x(1)\n";
        let mut modules = HashMap::new();
        modules.insert("game".to_string(), parse(game, "game.vpy"));
        modules.insert("physics".to_string(), parse(PHYSICS, "physics.vpy"));
        let unified = unify_modules(modules, "game").expect("unify");
        let defs = defined_symbols(&unified);
        assert!(defs.contains_key("MAIN") && defs.contains_key("LOOP"), "{defs:?}");
    }

    // ---- Error cases ----

    fn errors(r: UnifierResult<Module>) -> Vec<Diagnostic> {
        match r {
            Err(UnifierError::Unresolved(d)) => d,
            Err(e) => panic!("unexpected error kind: {e}"),
            Ok(_) => panic!("expected an error, unification succeeded"),
        }
    }

    #[test]
    fn missing_module_is_an_error_with_line() {
        // a lone main.vpy built without its project
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.clamp_x(1)\n";
        let diags = errors(unify(&[("main", main)]));
        assert_eq!(diags.len(), 1, "{diags:?}");
        assert_eq!(diags[0].module, "main");
        assert_eq!(diags[0].line, 1);
        assert!(diags[0].message.contains("module `physics` not found"), "{}", diags[0].message);
        assert!(diags[0].message.contains(".vpyproj"), "{}", diags[0].message);
    }

    #[test]
    fn missing_member_is_an_error() {
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.clamp_y(1)\n";
        let diags = errors(unify(&[("main", main), ("physics", PHYSICS)]));
        assert_eq!(diags.len(), 1, "{diags:?}");
        assert_eq!(diags[0].line, 7);
        assert!(diags[0].message.contains("no function, variable or const named `clamp_y`"), "{}", diags[0].message);
        assert!(diags[0].message.contains("clamp_x"), "should list what exists: {}", diags[0].message);
    }

    #[test]
    fn module_used_without_import_is_an_error() {
        let main = "def main():\n    pass\n\ndef loop():\n    x = physics.clamp_x(1)\n";
        let diags = errors(unify(&[("main", main), ("physics", PHYSICS)]));
        assert!(diags[0].message.contains("add `import physics`"), "{}", diags[0].message);
    }

    #[test]
    fn bad_from_import_is_an_error() {
        let main = "from physics import nope\n\ndef main():\n    pass\n\ndef loop():\n    pass\n";
        let diags = errors(unify(&[("main", main), ("physics", PHYSICS)]));
        assert!(diags[0].message.contains("cannot import `nope`"), "{}", diags[0].message);
    }

    #[test]
    fn calling_a_variable_is_an_error() {
        let main = "import physics\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.speed(1)\n";
        let diags = errors(unify(&[("main", main), ("physics", PHYSICS)]));
        assert!(diags[0].message.contains("not a function"), "{}", diags[0].message);
    }

    #[test]
    fn cross_module_label_collision_is_an_error() {
        let main = "import physics\nphysics_speed = 1\n\ndef main():\n    pass\n\ndef loop():\n    x = physics.speed\n";
        let diags = errors(unify(&[("main", main), ("physics", PHYSICS)]));
        assert!(diags.iter().any(|d| d.message.contains("clashes")), "{diags:?}");
    }

    #[test]
    fn value_methods_are_left_for_the_backend() {
        let main = "def main():\n    pass\n\ndef loop():\n    x = 5\n    y = x.abs()\n";
        let unified = unify(&[("main", main)]).expect("unify");
        let f = unified.items.iter().find_map(|i| match i { Item::Function(f) if f.name == "LOOP" => Some(f), _ => None }).unwrap();
        assert!(matches!(&f.body[1], Stmt::Assign { value: Expr::MethodCall(_), .. }));
    }
}
