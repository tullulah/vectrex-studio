//! PiTrex AST analyzer for builtin tree-shaking.
//!
//! Mirrors `m6809::helpers::analyze_module_helpers` — walks the module's
//! statements and expressions collecting the *uppercase* names of every
//! VPy builtin actually called. The result drives `emit_builtins`, which
//! only emits the ARM helpers for builtins that appear in the set (plus
//! their transitive dependencies, see `close_deps`).
//!
//! Conservative: any name we don't recognise is ignored. The "always-on"
//! helpers (newlib stubs, math, msg_system, etc.) are emitted
//! unconditionally in `emit_builtins`, so missing entries here just mean
//! the corresponding helper is omitted — never a miscompile.

use std::collections::HashSet;
use vpy_parser::{Module, Stmt, Expr, Item};

/// Walk the parsed module and return the set of builtin names called
/// (upper-cased). User-defined functions are not added; only builtin
/// calls matter for the tree-shake decision.
pub fn collect_used_builtins(module: &Module) -> HashSet<String> {
    let mut out = HashSet::new();
    for item in &module.items {
        match item {
            Item::Function(f) => {
                for s in &f.body {
                    walk_stmt(s, &mut out);
                }
            }
            Item::Const { value, .. } | Item::GlobalLet { value, .. } => {
                walk_expr(value, &mut out);
            }
            Item::ExprStatement(e) => walk_expr(e, &mut out),
            _ => {}
        }
    }
    close_deps(&mut out);
    out
}

fn walk_stmt(stmt: &Stmt, out: &mut HashSet<String>) {
    match stmt {
        Stmt::Assign { value, .. }            => walk_expr(value, out),
        Stmt::Let { value, .. }               => walk_expr(value, out),
        Stmt::CompoundAssign { value, .. }    => walk_expr(value, out),
        Stmt::Return(Some(e), _)              => walk_expr(e, out),
        Stmt::Expr(e, _)                      => walk_expr(e, out),
        Stmt::If { cond, body, elifs, else_body, .. } => {
            walk_expr(cond, out);
            for s in body { walk_stmt(s, out); }
            for (c, b) in elifs {
                walk_expr(c, out);
                for s in b { walk_stmt(s, out); }
            }
            if let Some(b) = else_body {
                for s in b { walk_stmt(s, out); }
            }
        }
        Stmt::While { cond, body, .. } => {
            walk_expr(cond, out);
            for s in body { walk_stmt(s, out); }
        }
        Stmt::For { start, end, step, body, .. } => {
            walk_expr(start, out);
            walk_expr(end, out);
            if let Some(s) = step { walk_expr(s, out); }
            for s in body { walk_stmt(s, out); }
        }
        Stmt::ForIn { iterable, body, .. } => {
            walk_expr(iterable, out);
            for s in body { walk_stmt(s, out); }
        }
        Stmt::Switch { expr, cases, default, .. } => {
            walk_expr(expr, out);
            for (c, b) in cases {
                walk_expr(c, out);
                for s in b { walk_stmt(s, out); }
            }
            if let Some(b) = default {
                for s in b { walk_stmt(s, out); }
            }
        }
        _ => {}
    }
}

fn walk_expr(expr: &Expr, out: &mut HashSet<String>) {
    match expr {
        Expr::Call(info) => {
            out.insert(info.name.to_uppercase());
            for a in &info.args { walk_expr(a, out); }
        }
        Expr::MethodCall(info) => {
            walk_expr(&info.target, out);
            for a in &info.args { walk_expr(a, out); }
        }
        Expr::Binary { left, right, .. } => { walk_expr(left, out); walk_expr(right, out); }
        Expr::Compare { left, right, .. } => { walk_expr(left, out); walk_expr(right, out); }
        Expr::Logic { left, right, .. } => { walk_expr(left, out); walk_expr(right, out); }
        Expr::Not(e) | Expr::BitNot(e) => walk_expr(e, out),
        Expr::Index { target, index } => { walk_expr(target, out); walk_expr(index, out); }
        Expr::FieldAccess { target, .. } => walk_expr(target, out),
        Expr::List(items) => for it in items { walk_expr(it, out); },
        _ => {}
    }
}

/// Close the set under static dependencies (one builtin's helper internally
/// calls another's). Adding a name here forces the corresponding helper to
/// be emitted even if user code doesn't call it directly.
fn close_deps(used: &mut HashSet<String>) {
    // Loop until no growth.
    loop {
        let before = used.len();
        for (trigger, deps) in BUILTIN_DEPS {
            if used.contains(*trigger) {
                for d in *deps { used.insert(d.to_string()); }
            }
        }
        if used.len() == before { break; }
    }
}

/// `(builtin name, [other builtin names whose helpers it also needs])`.
/// Keep concise — only list non-obvious transitive needs. Used to close
/// the set in `close_deps`. Most "internal" helpers (math, random, msg)
/// are emitted unconditionally so they don't need entries here.
const BUILTIN_DEPS: &[(&str, &[&str])] = &[
    // DRAW_LINE_REL piggy-backs on the absolute draw path.
    ("DRAW_LINE_REL",  &["DRAW_LINE"]),
    // PRINT_NUMBER reuses the print_text scaffolding.
    ("PRINT_NUMBER",   &["PRINT_TEXT"]),
    // DRAW_VECTOR_3D goes through the regular draw_vector path.
    ("DRAW_VECTOR_3D", &["DRAW_VECTOR"]),
    // Animation drawing fans into draw_vector_ex.
    ("DRAW_ANIM",      &["DRAW_VECTOR_EX"]),
    // Enemy update/draw both touch the per-frame draw_vector_ex / draw_anim.
    ("UPDATE_ENEMIES", &["SPAWN_ENEMIES", "DRAW_ANIM", "WANDER_SET_SPRITE"]),
    ("DRAW_ENEMIES",   &["DRAW_ANIM", "DRAW_VECTOR_EX"]),
    // Levels: SHOW_LEVEL/UPDATE_LEVEL ride on the music/SHOW scaffold.
    ("SHOW_LEVEL",     &["LOAD_LEVEL"]),
];
