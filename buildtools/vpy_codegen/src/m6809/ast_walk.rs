//! Exhaustive AST walker for the m6809 backend's "does the program use X?" scans.
//!
//! Every pre-codegen analysis (helper tree-shaking, RAM allocation, asset
//! filtering, string collection, auto-injected runtimes…) must see EVERY
//! statement and expression the code generator will later emit. Each scan used
//! to carry its own hand-written recursion with a `_ => {}` fallthrough, and
//! each one forgot a different node (`for` bodies, `if` conditions, `switch`,
//! compound assignments, index expressions…). The result was code that called a
//! helper the scan never asked for: `Undefined symbol: DRAW_LINE_WRAPPER`.
//!
//! The matches below are deliberately exhaustive — no wildcard arm — so adding a
//! node to `vpy_parser::Stmt` / `Expr` / `AssignTarget` / `Item` is a compile
//! error here until the walker learns to descend into it.

use vpy_parser::{AssignTarget, CallInfo, Expr, Item, Module, Stmt};

/// Callbacks for [`walk_code`] / [`walk_stmts`] / [`walk_expr`].
///
/// `stmt` is called for every statement (pre-order, before its children);
/// `expr` for every expression node, including every nested sub-expression.
pub trait Visitor<'a> {
    fn stmt(&mut self, _stmt: &'a Stmt) {}
    fn expr(&mut self, _expr: &'a Expr) {}
}

/// Adapter so a plain closure over expressions can be used as a [`Visitor`].
pub struct ExprFn<F>(pub F);

impl<'a, F: FnMut(&'a Expr)> Visitor<'a> for ExprFn<F> {
    fn expr(&mut self, expr: &'a Expr) {
        (self.0)(expr)
    }
}

/// Walk all code the m6809 backend emits: the body of every function.
///
/// Other items are listed explicitly so that a new item kind has to be classified:
/// - `GlobalLet` / `Const` initializers are evaluated by MAIN's startup code and are
///   reached through [`walk_global_inits`], not here.
/// - Struct methods/constructors, `VectorList`, `Export` and top-level expression
///   statements are not emitted by the m6809 backend.
pub fn walk_code<'a>(module: &'a Module, v: &mut dyn Visitor<'a>) {
    for item in &module.items {
        match item {
            Item::Function(func) => walk_stmts(&func.body, v),
            Item::Const { .. }
            | Item::GlobalLet { .. }
            | Item::VectorList { .. }
            | Item::ExprStatement(_)
            | Item::Export(_)
            | Item::StructDef(_) => {}
        }
    }
}

/// Walk the initializer expression of every `GlobalLet` and `Const` item.
pub fn walk_global_inits<'a>(module: &'a Module, v: &mut dyn Visitor<'a>) {
    for item in &module.items {
        match item {
            Item::Const { value, .. } | Item::GlobalLet { value, .. } => walk_expr(value, v),
            Item::Function(_)
            | Item::VectorList { .. }
            | Item::ExprStatement(_)
            | Item::Export(_)
            | Item::StructDef(_) => {}
        }
    }
}

/// Walk every function body AND every global initializer.
pub fn walk_module<'a>(module: &'a Module, v: &mut dyn Visitor<'a>) {
    walk_code(module, v);
    walk_global_inits(module, v);
}

pub fn walk_stmts<'a>(stmts: &'a [Stmt], v: &mut dyn Visitor<'a>) {
    for stmt in stmts {
        walk_stmt(stmt, v);
    }
}

pub fn walk_stmt<'a>(stmt: &'a Stmt, v: &mut dyn Visitor<'a>) {
    v.stmt(stmt);
    match stmt {
        Stmt::Assign { target, value, .. } => {
            walk_target(target, v);
            walk_expr(value, v);
        }
        Stmt::CompoundAssign { target, value, .. } => {
            walk_target(target, v);
            walk_expr(value, v);
        }
        Stmt::Let { value, .. } => walk_expr(value, v),
        Stmt::For { start, end, step, body, .. } => {
            walk_expr(start, v);
            walk_expr(end, v);
            if let Some(step) = step {
                walk_expr(step, v);
            }
            walk_stmts(body, v);
        }
        Stmt::ForIn { iterable, body, .. } => {
            walk_expr(iterable, v);
            walk_stmts(body, v);
        }
        Stmt::While { cond, body, .. } => {
            walk_expr(cond, v);
            walk_stmts(body, v);
        }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            walk_expr(cond, v);
            walk_stmts(body, v);
            for (elif_cond, elif_body) in elifs {
                walk_expr(elif_cond, v);
                walk_stmts(elif_body, v);
            }
            if let Some(else_body) = else_body {
                walk_stmts(else_body, v);
            }
        }
        Stmt::Switch { expr, cases, default, .. } => {
            walk_expr(expr, v);
            for (case_expr, case_body) in cases {
                walk_expr(case_expr, v);
                walk_stmts(case_body, v);
            }
            if let Some(default) = default {
                walk_stmts(default, v);
            }
        }
        Stmt::Expr(expr, _) => walk_expr(expr, v),
        Stmt::Return(value, _) => {
            if let Some(value) = value {
                walk_expr(value, v);
            }
        }
        Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => {}
    }
}

/// Walk the expressions inside an assignment target (`arr[i]`, `obj.field`).
/// A plain identifier target has no sub-expressions; callers that care about the
/// assigned name read it from the statement in [`Visitor::stmt`].
pub fn walk_target<'a>(target: &'a AssignTarget, v: &mut dyn Visitor<'a>) {
    match target {
        AssignTarget::Ident { .. } => {}
        AssignTarget::Index { target, index, .. } => {
            walk_expr(target, v);
            walk_expr(index, v);
        }
        AssignTarget::FieldAccess { target, .. } => walk_expr(target, v),
    }
}

pub fn walk_expr<'a>(expr: &'a Expr, v: &mut dyn Visitor<'a>) {
    v.expr(expr);
    match expr {
        Expr::Number(_) | Expr::StringLit(_) | Expr::Ident(_) | Expr::StructInit { .. } => {}
        Expr::Call(call) => {
            for arg in &call.args {
                walk_expr(arg, v);
            }
        }
        Expr::MethodCall(mc) => {
            walk_expr(&mc.target, v);
            for arg in &mc.args {
                walk_expr(arg, v);
            }
        }
        Expr::Binary { left, right, .. }
        | Expr::Compare { left, right, .. }
        | Expr::Logic { left, right, .. } => {
            walk_expr(left, v);
            walk_expr(right, v);
        }
        Expr::Not(inner) | Expr::BitNot(inner) => walk_expr(inner, v),
        Expr::List(items) => {
            for item in items {
                walk_expr(item, v);
            }
        }
        Expr::Index { target, index } => {
            walk_expr(target, v);
            walk_expr(index, v);
        }
        Expr::FieldAccess { target, .. } => walk_expr(target, v),
    }
}

/// Call `f` for every expression node in the module (function bodies + global initializers).
pub fn for_each_expr<'a>(module: &'a Module, f: impl FnMut(&'a Expr)) {
    walk_module(module, &mut ExprFn(f));
}

/// Call `f` for every expression node in the given statements.
pub fn for_each_expr_in_stmts<'a>(stmts: &'a [Stmt], f: impl FnMut(&'a Expr)) {
    walk_stmts(stmts, &mut ExprFn(f));
}

/// Call `f` for every call expression in the module (builtin or user function).
pub fn for_each_call<'a>(module: &'a Module, mut f: impl FnMut(&'a CallInfo)) {
    for_each_expr(module, |e| {
        if let Expr::Call(call) = e {
            f(call)
        }
    });
}

/// True if any call in the module satisfies `pred`.
pub fn any_call(module: &Module, mut pred: impl FnMut(&CallInfo) -> bool) -> bool {
    let mut found = false;
    for_each_call(module, |c| {
        if !found && pred(c) {
            found = true;
        }
    });
    found
}

/// True if the module calls any of `names` (case-insensitive; pass upper-case names).
pub fn calls_any(module: &Module, names: &[&str]) -> bool {
    any_call(module, |c| {
        let up = c.name.to_ascii_uppercase();
        names.iter().any(|n| *n == up)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse(src: &str) -> Module {
        let tokens = vpy_parser::lex(src).expect("lex");
        vpy_parser::parse_tokens(&tokens, "test.vpy").expect("parse")
    }

    /// Every statement/expression position a call can hide in must be reached.
    #[test]
    fn finds_calls_in_every_position() {
        let src = "\
xs = [1, 2, 3]
g = ABS(-1)

def helper(a):
    return SIN(a)

def main():
    for i in range(0, 3):
        A_FOR()
    for v in xs:
        A_FORIN()
    while B_WHILE_COND() > 0:
        B_WHILE()
    if C_IF_COND() > 0:
        C_IF()
    elif C_ELIF_COND() > 0:
        C_ELIF()
    else:
        C_ELSE()
    switch D_SWITCH():
        case 1:
            D_CASE()
        default:
            D_DEFAULT()
    xs[E_INDEX()] = 1
    x = 0
    x += F_COMPOUND()
    y = xs[G_READ()] + 1

def loop():
    pass
";
        let module = parse(src);
        let mut seen = std::collections::HashSet::new();
        for_each_call(&module, |c| {
            seen.insert(c.name.to_ascii_uppercase());
        });
        for name in [
            "ABS", "SIN", "A_FOR", "A_FORIN", "B_WHILE_COND", "B_WHILE", "C_IF_COND", "C_IF",
            "C_ELIF_COND", "C_ELIF", "C_ELSE", "D_SWITCH", "D_CASE", "D_DEFAULT", "E_INDEX",
            "F_COMPOUND", "G_READ",
        ] {
            assert!(seen.contains(name), "walker missed call {name}; saw {seen:?}");
        }
    }
}
