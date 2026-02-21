// Collectors - Symbol and variable collection functions for M6809 backend
use crate::ast::{Expr, Item, Module};
use super::{collect_expr_syms, collect_stmt_syms, collect_locals};
use std::collections::BTreeSet;

pub fn collect_all_vars(module: &Module) -> Vec<String> {
    use std::collections::BTreeSet;
    let mut all_vars = BTreeSet::new();
    for item in &module.items {
        if let Item::Function(f) = item {
            for stmt in &f.body { collect_stmt_syms(stmt, &mut all_vars); }
        } else if let Item::GlobalLet { name, .. } = item { 
            all_vars.insert(name.clone()); 
        } else if let Item::ExprStatement(expr) = item {
            collect_expr_syms(expr, &mut all_vars);
        }
    }
    // Don't remove locals - we need ALL variables for assembly generation
    all_vars.into_iter().collect()
}

// collect_symbols: gather variable identifiers.
#[allow(dead_code)]
pub fn collect_symbols(module: &Module) -> Vec<String> {
    use std::collections::BTreeSet;
    let mut globals = BTreeSet::new();
    let mut locals = BTreeSet::new();
    
    // First pass: collect global names
    let global_names: Vec<String> = module.items.iter()
        .filter_map(|item| {
            if let Item::GlobalLet { name, .. } = item {
                Some(name.clone())
            } else {
                None
            }
        })
        .collect();
    
    for item in &module.items {
        if let Item::Function(f) = item {
            for stmt in &f.body { collect_stmt_syms(stmt, &mut globals); }
            for l in collect_locals(&f.body, &global_names) { locals.insert(l); }
        } else if let Item::GlobalLet { name, .. } = item { 
            globals.insert(name.clone()); 
        } else if let Item::ExprStatement(expr) = item {
            collect_expr_syms(expr, &mut globals);
        }
    }
    for l in &locals { globals.remove(l); }
    globals.into_iter().collect()
}

// NEW: Collect global variables with their initial values
pub fn collect_global_vars(module: &Module) -> Vec<(String, Expr)> {
    let mut vars = Vec::new();
    for item in &module.items {
        if let Item::GlobalLet { name, value, .. } = item {
            vars.push((name.clone(), value.clone()));
        }
    }
    vars
}

/// Collect global variables WITH source line numbers
pub fn collect_global_vars_with_line(module: &Module) -> Vec<(String, Expr, usize)> {
    let mut vars = Vec::new();
    for item in &module.items {
        if let Item::GlobalLet { name, value, source_line, .. } = item {
            vars.push((name.clone(), value.clone(), *source_line));
        }
    }
    vars
}

/// Collect constant declarations (const name = value)
/// These are stored in ROM only, not allocated as RAM variables
pub fn collect_const_vars(module: &Module) -> Vec<(String, Expr)> {
    let mut consts = Vec::new();
    for item in &module.items {
        if let Item::Const { name, value, .. } = item {
            consts.push((name.clone(), value.clone()));
        }
    }
    consts
}

/// Collect constant variables WITH source line numbers
pub fn collect_const_vars_with_line(module: &Module) -> Vec<(String, Expr, usize)> {
    let mut consts = Vec::new();
    for item in &module.items {
        if let Item::Const { name, value, source_line, .. } = item {
            consts.push((name.clone(), value.clone(), *source_line));
        }
    }
    consts
}
