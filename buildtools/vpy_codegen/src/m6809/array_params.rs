//! Element type of array parameters (m6809).
//!
//! An array passed to a function is passed as its base address: `f(xs)` stores
//! the address of `xs`'s data in the parameter slot, and `p[i]` inside `f` reads
//! `*(p + i * element_size)`. Parameters carry no type annotation, so the
//! element size of each parameter is taken from the arrays passed at the call
//! sites:
//!
//! - a global array argument contributes its declared element type
//!   (`xs: u8 = [...]` → u8, untyped → i16);
//! - a parameter forwarded to another function contributes whatever that
//!   parameter receives (resolved to a fixed point);
//! - any other argument (a number, a scalar variable, an expression) is an
//!   address the compiler cannot type and contributes nothing.
//!
//! A parameter that is indexed and receives arrays of two different element
//! types is a compile error (one function body indexes with one stride). A
//! parameter that receives no typed array is indexed with 16-bit elements.

use super::ast_walk::{self, Visitor};
use super::context::VarSize;
use std::collections::{BTreeMap, HashMap, HashSet};
use vpy_parser::{AssignTarget, Expr, Function, Item, Module, Stmt};

/// Where the value of one call argument comes from.
enum Source {
    /// A global array of this element type (named, for messages).
    Array(VarSize, String),
    /// A parameter of the calling function: (caller label, parameter index).
    Param(String, usize),
}

/// One `callee(..., arg, ...)` fact.
struct Fact {
    callee: String,
    index: usize,
    source: Source,
    line: usize,
}

/// Same element layout? (16-bit loads are the same whether signed or not.)
fn normalize(v: VarSize) -> VarSize {
    if v.bytes == 2 { VarSize::default_i16() } else { v }
}

/// Parameters of `func` (lower-case name → index) used as arrays: indexed in an
/// expression, assigned through an index, or iterated by `for .. in`.
fn indexed_params(func: &Function) -> HashSet<usize> {
    struct V<'f> {
        params: &'f [String],
        used: HashSet<usize>,
    }
    impl V<'_> {
        fn mark(&mut self, e: &Expr) {
            if let Expr::Ident(id) = e {
                if let Some(i) = self.params.iter().position(|p| p.eq_ignore_ascii_case(&id.name)) {
                    self.used.insert(i);
                }
            }
        }
    }
    impl<'a> Visitor<'a> for V<'_> {
        fn stmt(&mut self, stmt: &'a Stmt) {
            match stmt {
                Stmt::Assign { target: AssignTarget::Index { target, .. }, .. }
                | Stmt::CompoundAssign { target: AssignTarget::Index { target, .. }, .. } => self.mark(target),
                Stmt::ForIn { iterable, .. } => self.mark(iterable),
                _ => {}
            }
        }
        fn expr(&mut self, expr: &'a Expr) {
            if let Expr::Index { target, .. } = expr {
                self.mark(target);
            }
        }
    }
    let mut v = V { params: &func.params, used: HashSet::new() };
    ast_walk::walk_stmts(&func.body, &mut v);
    v.used
}

/// Infer the element type of every indexed array parameter.
///
/// Returns m6809 function label → parameter name (lower-case) → element size,
/// for the parameters whose element type is known; the others are 16-bit.
pub fn analyze(module: &Module) -> Result<HashMap<String, HashMap<String, VarSize>>, String> {
    let label = |name: &str| vpy_parser::symbols::m6809_label(name);

    let global_arrays: HashMap<&str, VarSize> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::GlobalLet { name, value: Expr::List(_), type_annotation, .. }
            | Item::Const { name, value: Expr::List(_), type_annotation, .. } => {
                Some((name.as_str(), VarSize::from_annotation(type_annotation)))
            }
            _ => None,
        })
        .collect();

    let functions: HashMap<String, &Function> = module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::Function(f) => Some((label(&f.name), f)),
            _ => None,
        })
        .collect();

    // Call-site facts.
    let mut facts: Vec<Fact> = Vec::new();
    for item in &module.items {
        let Item::Function(caller) = item else { continue };
        let caller_label = label(&caller.name);
        ast_walk::for_each_expr_in_stmts(&caller.body, |e| {
            let Expr::Call(call) = e else { return };
            let callee = label(&call.name);
            if !functions.contains_key(&callee) {
                return;
            }
            for (index, arg) in call.args.iter().enumerate() {
                let Expr::Ident(id) = arg else { continue };
                let source = if let Some(p) = caller.params.iter().position(|p| p.eq_ignore_ascii_case(&id.name)) {
                    Source::Param(caller_label.clone(), p)
                } else if let Some(v) = global_arrays.get(id.name.as_str()) {
                    Source::Array(normalize(*v), id.name.clone())
                } else {
                    continue;
                };
                facts.push(Fact { callee: callee.clone(), index, source, line: call.source_line });
            }
        });
    }

    // Element types each (function, parameter) receives, with the first array
    // (name, call line) that brought each type — to a fixed point, so a
    // parameter forwarded through any chain of calls gets its callers' types.
    type Key = (String, usize);
    let mut received: HashMap<Key, BTreeMap<VarSize, (String, usize)>> = HashMap::new();
    loop {
        let mut changed = false;
        for fact in &facts {
            let incoming: Vec<(VarSize, (String, usize))> = match &fact.source {
                Source::Array(v, name) => vec![(*v, (name.clone(), fact.line))],
                Source::Param(f, i) => received
                    .get(&(f.clone(), *i))
                    .map(|m| m.iter().map(|(v, o)| (*v, o.clone())).collect())
                    .unwrap_or_default(),
            };
            let slot = received.entry((fact.callee.clone(), fact.index)).or_default();
            for (v, origin) in incoming {
                if !slot.contains_key(&v) {
                    slot.insert(v, origin);
                    changed = true;
                }
            }
        }
        if !changed {
            break;
        }
    }

    let mut out: HashMap<String, HashMap<String, VarSize>> = HashMap::new();
    let mut errors = Vec::new();
    let mut names: Vec<&String> = functions.keys().collect();
    names.sort();
    for fname in names {
        let func = functions[fname];
        let mut used: Vec<usize> = indexed_params(func).into_iter().collect();
        used.sort_unstable();
        for i in used {
            let Some(types) = received.get(&(fname.clone(), i)) else { continue };
            let param = &func.params[i];
            match types.len() {
                0 => {}
                1 => {
                    let v = *types.keys().next().unwrap();
                    out.entry(fname.clone()).or_default().insert(param.to_lowercase(), v);
                }
                _ => {
                    let listing: Vec<String> = types
                        .iter()
                        .map(|(v, (array, line))| format!("`{array}` ({}) at line {line}", v.type_name()))
                        .collect();
                    errors.push(format!(
                        "line {}: parameter `{param}` of `{}` is indexed as an array, but it receives arrays \
                         with different element types: {}. One function indexes with one element size on m6809; \
                         pass arrays of the same type (u8/i8 = 1 byte, untyped/i16/u16 = 2 bytes) or use a second function.",
                        func.line,
                        func.name,
                        listing.join(" and ")
                    ));
                }
            }
        }
    }
    if errors.is_empty() { Ok(out) } else { Err(errors.join("\n")) }
}
