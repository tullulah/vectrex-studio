//! VPy Unifier: Phase 3 of buildtools compiler pipeline
//!
//! Resolves imports, validates symbols, and merges multiple modules into one
//!
//! # Module Structure
//!
//! - `error.rs`: Error types (UnifierError, UnifierResult)
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
//! 1. **Load & Graph**: Load all .vpy files, build dependency graph
//! 2. **Cycle Detection**: Reject circular imports
//! 3. **Topological Sort**: Determine merge order (dependencies first)
//! 4. **Symbol Renaming**: Prefix imported symbols (INPUT_*, GRAPHICS_*, etc.)
//! 5. **Merge**: Combine items into single module
//! 6. **Reference Fixing**: Update all calls/accesses to use renamed symbols
//! 7. **Validation**: Ensure all symbols are defined

pub mod error;
pub mod graph;
pub mod resolver;
pub mod scope;
pub mod types;
pub mod visitor;

pub use error::{UnifierError, UnifierResult};
pub use graph::ModuleGraph;
pub use resolver::SymbolResolver;
pub use scope::Scope;
pub use types::VarType;
pub use visitor::AstVisitor;
pub use vpy_parser::ast::{Module, Item, ImportDecl};

/// Unify multiple modules into a single resolved module
///
/// # Arguments
/// * `modules` - Map of module names to parsed Modules from Phase 2
///
/// # Returns
/// * `UnifierResult<Module>` - Unified module or error
///
/// # Process
/// 1. Build dependency graph
/// 2. Check for circular imports
/// 3. Topologically sort modules
/// 4. Rename symbols based on module prefix
/// 5. Merge into single module
/// 6. Validate all references
pub fn unify_modules(
    modules: std::collections::HashMap<String, Module>,
    entry_module: &str,
) -> UnifierResult<Module> {
    // Phase 3.1: Build graph
    let mut graph = ModuleGraph::new();
    for (name, module) in modules {
        graph.add_module(name, module);
    }

    // Phase 3.2: Detect cycles
    if let Some(cycle) = graph.detect_cycles() {
        return Err(UnifierError::CircularDependency(format!("{:?}", cycle)));
    }

    // Phase 3.3: Topologically sort
    let sort_order = graph.topological_sort()?;

    // Phase 3.4-3.5: Symbol resolution and merge
    let mut resolver = SymbolResolver::new();
    let mut merged_items = Vec::new();
    let mut merged_meta = Default::default();

    for module_name in sort_order {
        let prefix = resolver.register_module(&module_name);
        if let Some(module) = graph.get_module(&module_name) {
            // For entry module, use its metadata
            if module_name == entry_module {
                merged_meta = module.meta.clone();
            }

            // Add items with renamed symbols (Phase 3.5: Apply prefix)
            for item in &module.items {
                let renamed_item = rename_item_symbols(item, &prefix, &resolver);
                merged_items.push(renamed_item);
            }
        }
    }

    // Phase 3.6: Rewrite references (FieldAccess, MethodCall) to use unified names
    let rewritten_items = rewrite_references(merged_items, &resolver);

    Ok(Module {
        items: rewritten_items,
        meta: merged_meta,
        imports: vec![],  // All imports resolved, empty in unified module
    })
}

/// Rename all symbols in an item with the given prefix
/// Also rewrites references inside function bodies
fn rename_item_symbols(item: &Item, prefix: &str, _resolver: &SymbolResolver) -> Item {
    match item {
        Item::Function(func) => {
            let mut new_func = func.clone();
            new_func.name = apply_prefix(prefix, &func.name);
            
            // CRITICAL: Also rewrite references inside function body  
            // Apply the SAME prefix to all identifiers within this function
            new_func.body = new_func.body.into_iter()
                .map(|stmt| rewrite_stmt_with_prefix(stmt, prefix))
                .collect();
            
            Item::Function(new_func)
        }
        Item::GlobalLet { name, type_annotation, value, source_line } => {
            Item::GlobalLet {
                name: apply_prefix(prefix, name),
                type_annotation: type_annotation.clone(),
                value: value.clone(),
                source_line: *source_line,
            }
        }
        Item::Const { name, type_annotation, value, source_line } => {
            Item::Const {
                name: apply_prefix(prefix, name),
                type_annotation: type_annotation.clone(),
                value: value.clone(),
                source_line: *source_line,
            }
        }
        _ => item.clone(),  // Other items unchanged
    }
}

/// Rewrite all identifiers in a statement with the given prefix
/// This is used within a single module to make all references consistent with definitions
fn rewrite_stmt_with_prefix(stmt: vpy_parser::ast::Stmt, prefix: &str) -> vpy_parser::ast::Stmt {
    use vpy_parser::ast::*;
    
    match stmt {
        Stmt::Assign { target, value, source_line } => {
            Stmt::Assign {
                target: rewrite_assign_target_with_prefix(target, prefix),
                value: rewrite_expr_with_prefix(value, prefix),
                source_line,
            }
        }
        // Add other statement types as needed...
        _ => stmt,  // TODO: Handle other statement types
    }
}

/// Rewrite assign target identifiers with prefix
fn rewrite_assign_target_with_prefix(target: vpy_parser::ast::AssignTarget, prefix: &str) -> vpy_parser::ast::AssignTarget {
    use vpy_parser::ast::*;
    
    match target {
        AssignTarget::Ident { name, source_line, col } => {
            AssignTarget::Ident {
                name: apply_prefix(prefix, &name),
                source_line,
                col,
            }
        }
        AssignTarget::Index { target: array_expr, index, source_line, col } => {
            AssignTarget::Index {
                target: Box::new(rewrite_expr_with_prefix(*array_expr, prefix)),
                index: Box::new(rewrite_expr_with_prefix(*index, prefix)),
                source_line,
                col,
            }
        }
        _ => target,
    }
}

/// Rewrite expression identifiers with prefix
fn rewrite_expr_with_prefix(expr: vpy_parser::ast::Expr, prefix: &str) -> vpy_parser::ast::Expr {
    use vpy_parser::ast::*;
    
    match expr {
        Expr::Ident(ident) => {
            Expr::Ident(IdentInfo {
                name: apply_prefix(prefix, &ident.name),
                source_line: ident.source_line,
                col: ident.col,
            })
        }
        Expr::Index { target, index } => {
            Expr::Index {
                target: Box::new(rewrite_expr_with_prefix(*target, prefix)),
                index: Box::new(rewrite_expr_with_prefix(*index, prefix)),
            }
        }
        // Literals don't need rewriting
        _ => expr,
    }
}

/// Apply prefix to a symbol name (if prefix is non-empty)
fn apply_prefix(prefix: &str, name: &str) -> String {
    if prefix.is_empty() {
        // No prefix - convert to uppercase for consistency
        name.to_uppercase()
    } else {
        // With prefix - convert both to uppercase (e.g., INPUT_GET_INPUT)
        format!("{}_{}", prefix.to_uppercase(), name.to_uppercase())
    }
}

/// Rewrite all references in items to use unified symbol names
/// Transforms:
/// - FieldAccess(module, field) → Ident(MODULE_field)
/// - MethodCall(module.method()) → Call(MODULE_method())
fn rewrite_references(items: Vec<Item>, resolver: &SymbolResolver) -> Vec<Item> {
    use vpy_parser::ast::*;
    
    items.into_iter().map(|item| {
        match item {
            Item::Function(mut func) => {
                // Rewrite all statements in function body
                func.body = func.body.into_iter()
                    .map(|stmt| rewrite_stmt(stmt, resolver))
                    .collect();
                Item::Function(func)
            }
            Item::GlobalLet { name, type_annotation, value, source_line } => {
                Item::GlobalLet {
                    name,
                    type_annotation,
                    value: rewrite_expr(value, resolver),
                    source_line,
                }
            }
            Item::Const { name, type_annotation, value, source_line } => {
                Item::Const {
                    name,
                    type_annotation,
                    value: rewrite_expr(value, resolver),
                    source_line,
                }
            }
            other => other,
        }
    }).collect()
}

/// Rewrite expressions in a statement
fn rewrite_stmt(stmt: vpy_parser::ast::Stmt, resolver: &SymbolResolver) -> vpy_parser::ast::Stmt {
    use vpy_parser::ast::*;
    
    match stmt {
        Stmt::Assign { target, value, source_line } => {
            Stmt::Assign {
                target: rewrite_assign_target(target, resolver),
                value: rewrite_expr(value, resolver),
                source_line,
            }
        }
        Stmt::If { cond, body, elifs, else_body, source_line } => {
            Stmt::If {
                cond: rewrite_expr(cond, resolver),
                body: body.into_iter().map(|s| rewrite_stmt(s, resolver)).collect(),
                elifs: elifs.into_iter().map(|(c, b)| {
                    (rewrite_expr(c, resolver), b.into_iter().map(|s| rewrite_stmt(s, resolver)).collect())
                }).collect(),
                else_body: else_body.map(|b| b.into_iter().map(|s| rewrite_stmt(s, resolver)).collect()),
                source_line,
            }
        }
        Stmt::While { cond, body, source_line } => {
            Stmt::While {
                cond: rewrite_expr(cond, resolver),
                body: body.into_iter().map(|s| rewrite_stmt(s, resolver)).collect(),
                source_line,
            }
        }
        Stmt::For { var, start, end, step, body, source_line } => {
            Stmt::For {
                var,
                start: rewrite_expr(start, resolver),
                end: rewrite_expr(end, resolver),
                step: step.map(|s| rewrite_expr(s, resolver)),
                body: body.into_iter().map(|s| rewrite_stmt(s, resolver)).collect(),
                source_line,
            }
        }
        Stmt::ForIn { var, iterable, body, source_line } => {
            Stmt::ForIn {
                var,
                iterable: rewrite_expr(iterable, resolver),
                body: body.into_iter().map(|s| rewrite_stmt(s, resolver)).collect(),
                source_line,
            }
        }
        Stmt::Return(value, source_line) => {
            Stmt::Return(value.map(|v| rewrite_expr(v, resolver)), source_line)
        }
        Stmt::Expr(expr, source_line) => {
            Stmt::Expr(rewrite_expr(expr, resolver), source_line)
        }
        Stmt::Let { name, type_annotation, value, source_line } => {
            Stmt::Let {
                name,
                type_annotation,
                value: rewrite_expr(value, resolver),
                source_line,
            }
        }
        Stmt::Switch { expr, cases, default, source_line } => {
            Stmt::Switch {
                expr: rewrite_expr(expr, resolver),
                cases: cases.into_iter().map(|(e, b)| {
                    (rewrite_expr(e, resolver), b.into_iter().map(|s| rewrite_stmt(s, resolver)).collect())
                }).collect(),
                default: default.map(|b| b.into_iter().map(|s| rewrite_stmt(s, resolver)).collect()),
                source_line,
            }
        }
        Stmt::CompoundAssign { target, op, value, source_line } => {
            Stmt::CompoundAssign {
                target: rewrite_assign_target(target, resolver),
                op,
                value: rewrite_expr(value, resolver),
                source_line,
            }
        }
        other => other,
    }
}

/// Rewrite assign target (may contain FieldAccess)
fn rewrite_assign_target(target: vpy_parser::ast::AssignTarget, resolver: &SymbolResolver) -> vpy_parser::ast::AssignTarget {
    use vpy_parser::ast::*;
    
    match target {
        AssignTarget::Ident { name, source_line, col } => {
            // Convert to uppercase for consistency
            AssignTarget::Ident { 
                name: name.to_uppercase(), 
                source_line, 
                col 
            }
        }
        AssignTarget::Index { target, index, source_line, col } => {
            AssignTarget::Index {
                target: Box::new(rewrite_expr(*target, resolver)),
                index: Box::new(rewrite_expr(*index, resolver)),
                source_line,
                col,
            }
        }
        AssignTarget::FieldAccess { target, field, source_line, col } => {
            // Convert module.field → MODULE_field
            if let Expr::Ident(ident) = *target {
                let resolved = resolver.resolve_field_access(&ident.name, &field);
                AssignTarget::Ident {
                    name: resolved,
                    source_line,
                    col,
                }
            } else {
                AssignTarget::FieldAccess {
                    target: Box::new(rewrite_expr(*target, resolver)),
                    field,
                    source_line,
                    col,
                }
            }
        }
    }
}

/// Rewrite an expression to use unified symbol names
fn rewrite_expr(expr: vpy_parser::ast::Expr, resolver: &SymbolResolver) -> vpy_parser::ast::Expr {
    use vpy_parser::ast::*;
    
    match expr {
        // FieldAccess: module.symbol → MODULE_symbol
        Expr::FieldAccess { target, field, source_line, col } => {
            if let Expr::Ident(ident) = *target {
                // This is module.field - resolve it
                let resolved_name = resolver.resolve_field_access(&ident.name, &field);
                Expr::Ident(IdentInfo {
                    name: resolved_name,
                    source_line: ident.source_line,
                    col: ident.col,
                })
            } else {
                // Nested field access - recurse
                Expr::FieldAccess {
                    target: Box::new(rewrite_expr(*target, resolver)),
                    field,
                    source_line,
                    col,
                }
            }
        }
        
        // MethodCall: module.method() → MODULE_method()
        Expr::MethodCall(call) => {
            if let Expr::Ident(ident) = *call.target {
                // This is module.method() - convert to regular Call
                let resolved_name = resolver.resolve_field_access(&ident.name, &call.method_name);
                Expr::Call(CallInfo {
                    name: resolved_name,
                    args: call.args.into_iter().map(|a| rewrite_expr(a, resolver)).collect(),
                    source_line: call.source_line,
                    col: call.col,
                })
            } else {
                // Nested method call - recurse
                Expr::MethodCall(MethodCallInfo {
                    target: Box::new(rewrite_expr(*call.target, resolver)),
                    method_name: call.method_name,
                    args: call.args.into_iter().map(|a| rewrite_expr(a, resolver)).collect(),
                    source_line: call.source_line,
                    col: call.col,
                })
            }
        }
        
        // Regular Call: rewrite arguments AND normalize function name
        Expr::Call(call) => {
            Expr::Call(CallInfo {
                name: call.name.to_uppercase(),  // CRITICAL FIX: Normalize function names to uppercase
                args: call.args.into_iter().map(|a| rewrite_expr(a, resolver)).collect(),
                source_line: call.source_line,
                col: call.col,
            })
        }
        
        // Binary/Compare/Logic: rewrite both sides
        Expr::Binary { op, left, right } => {
            Expr::Binary {
                op,
                left: Box::new(rewrite_expr(*left, resolver)),
                right: Box::new(rewrite_expr(*right, resolver)),
            }
        }
        Expr::Compare { op, left, right } => {
            Expr::Compare {
                op,
                left: Box::new(rewrite_expr(*left, resolver)),
                right: Box::new(rewrite_expr(*right, resolver)),
            }
        }
        Expr::Logic { op, left, right } => {
            Expr::Logic {
                op,
                left: Box::new(rewrite_expr(*left, resolver)),
                right: Box::new(rewrite_expr(*right, resolver)),
            }
        }
        
        // Unary: rewrite operand
        Expr::Not(e) => Expr::Not(Box::new(rewrite_expr(*e, resolver))),
        Expr::BitNot(e) => Expr::BitNot(Box::new(rewrite_expr(*e, resolver))),
        
        // List: rewrite all elements
        Expr::List(elements) => {
            Expr::List(elements.into_iter().map(|e| rewrite_expr(e, resolver)).collect())
        }
        
        // Index: rewrite both target and index
        Expr::Index { target, index } => {
            Expr::Index {
                target: Box::new(rewrite_expr(*target, resolver)),
                index: Box::new(rewrite_expr(*index, resolver)),
            }
        }
        
        // Ident: Convert to uppercase for consistency with renamed definitions
        Expr::Ident(mut ident) => {
            // All variable/function names should be uppercase after unification
            // (matching the renamed definitions from rename_item_symbols)
            ident.name = ident.name.to_uppercase();
            Expr::Ident(ident)
        }
        
        // Literals and other simple expressions - no rewriting needed
        other => other,
    }
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
}
