// Utils - Helper functions for M6809 backend
use std::sync::atomic::{AtomicUsize, Ordering};
use std::collections::BTreeSet;
use crate::ast::{Expr, Stmt};

/// Generate a unique label with the given prefix
pub fn fresh_label(prefix: &str) -> String {
    static COUNTER: AtomicUsize = AtomicUsize::new(0);
    let id = COUNTER.fetch_add(1, Ordering::Relaxed);
    format!("{}_{}", prefix, id)
}

/// Check if an expression is a power of two constant
pub fn power_of_two_const(expr: &Expr) -> Option<u32> {
    if let Expr::Number(n) = expr {
        let val = *n as u32 & 0xFFFF;
        if val >= 2 && (val & (val - 1)) == 0 {
            return (0..16).find(|s| (1u32 << s) == val);
        }
    }
    None
}

/// Format an expression reference for debugging
pub fn format_expr_ref(e: &Expr) -> String {
    match e {
        Expr::Ident(n) => format!("I:{}", n.name),
        Expr::Number(v) => format!("N:{}", v),
        Expr::StringLit(s) => format!("S:{}", s),
        Expr::Call(ci) => format!("C:{}", ci.name),
        Expr::MethodCall(mc) => format!("M:{}.{}", format_expr_ref(&mc.target), mc.method_name),
        Expr::Index { target, index } => {
            // CRITICAL: Include both array name and index to distinguish different arrays
            // e.g., enemy_x[i] vs enemy_vx[i] should be different
            format!("IDX:{}[{}]", format_expr_ref(target), format_expr_ref(index))
        }
        _ => "?".to_string(),
    }
}

/// Collect all expression identifiers
pub fn collect_expr_syms(expr: &Expr, set: &mut BTreeSet<String>) {
    match expr {
        Expr::Ident(n) => { set.insert(n.name.clone()); }
        Expr::Call(ci) => { for a in &ci.args { collect_expr_syms(a, set); } }
        Expr::MethodCall(mc) => { 
            collect_expr_syms(&mc.target, set);
            for a in &mc.args { collect_expr_syms(a, set); } 
        }
        Expr::Binary { left, right, .. }
        | Expr::Compare { left, right, .. }
        | Expr::Logic { left, right, .. } => {
            collect_expr_syms(left, set);
            collect_expr_syms(right, set);
        }
        Expr::Not(inner) | Expr::BitNot(inner) => collect_expr_syms(inner, set),
        Expr::Number(_) | Expr::StringLit(_) => {}
        Expr::List(elements) => {
            for elem in elements {
                collect_expr_syms(elem, set);
            }
        }
        Expr::Index { target, index } => {
            collect_expr_syms(target, set);
            collect_expr_syms(index, set);
        }
        Expr::StructInit { .. } => {} // Phase 3 - no identifiers in struct init
        Expr::FieldAccess { target, .. } => collect_expr_syms(target, set),
    }
}

/// Collect all statement symbols
pub fn collect_stmt_syms(stmt: &Stmt, set: &mut BTreeSet<String>) {
    match stmt {
        Stmt::Assign { target, value, .. } => {
            match target {
                crate::ast::AssignTarget::Ident { name, .. } => {
                    set.insert(name.clone());
                }
                crate::ast::AssignTarget::Index { target: array_expr, index, .. } => {
                    if let Expr::Ident(id) = &**array_expr {
                        set.insert(id.name.clone());
                    }
                    collect_expr_syms(array_expr, set);
                    collect_expr_syms(index, set);
                }
                crate::ast::AssignTarget::FieldAccess { target, .. } => {
                    // Phase 3 - collect symbols from target expression
                    collect_expr_syms(target, set);
                }
            }
            collect_expr_syms(value, set);
        }
        Stmt::Let { name, value, .. } => {
            set.insert(name.clone());
            collect_expr_syms(value, set);
        }
        Stmt::Expr(e, ..) | Stmt::Return(Some(e), _) => {
            collect_expr_syms(e, set);
        }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            collect_expr_syms(cond, set);
            for s in body {
                collect_stmt_syms(s, set);
            }
            for (elif_cond, elif_body) in elifs {
                collect_expr_syms(elif_cond, set);
                for s in elif_body {
                    collect_stmt_syms(s, set);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    collect_stmt_syms(s, set);
                }
            }
        }
        Stmt::While { cond, body, .. } => {
            collect_expr_syms(cond, set);
            for s in body {
                collect_stmt_syms(s, set);
            }
        }
        Stmt::For { var, body, .. } => {
            set.insert(var.clone());
            for s in body {
                collect_stmt_syms(s, set);
            }
        }
        Stmt::ForIn { iterable, body, .. } => {
            collect_expr_syms(iterable, set);
            for s in body {
                collect_stmt_syms(s, set);
            }
        }
        Stmt::Switch { expr, cases, default, .. } => {
            collect_expr_syms(expr, set);
            for (val, case_body) in cases {
                collect_expr_syms(val, set);
                for s in case_body {
                    collect_stmt_syms(s, set);
                }
            }
            if let Some(default_body) = default {
                for s in default_body {
                    collect_stmt_syms(s, set);
                }
            }
        }
        _ => {}
    }
}

/// Collect local variables from statements
pub fn collect_locals(stmts: &[Stmt], global_names: &[String]) -> Vec<String> {
    collect_locals_with_params(stmts, global_names, &[])
}

pub fn collect_locals_with_params(stmts: &[Stmt], global_names: &[String], params: &[String]) -> Vec<String> {
    fn walk(s: &Stmt, set: &mut BTreeSet<String>, globals: &[String]) {
        // Explicit local declaration (old `let` keyword, now unused)
        if let Stmt::Let { name, .. } = s {
            set.insert(name.clone());
        }
        // Assignment to new name (not in globals) is treated as local declaration
        if let Stmt::Assign { target, .. } = s {
            if let crate::ast::AssignTarget::Ident { name, .. } = target {
                // If not a global, treat as local declaration
                if !globals.contains(name) {
                    set.insert(name.clone());
                }
            }
        }
        match s {
            Stmt::If { body, elifs, else_body, .. } => {
                for b in body { walk(b, set, globals); }
                for (_, elif_body) in elifs {
                    for b in elif_body { walk(b, set, globals); }
                }
                if let Some(else_stmts) = else_body {
                    for b in else_stmts { walk(b, set, globals); }
                }
            }
            Stmt::While { body, .. } | Stmt::For { body, .. } | Stmt::ForIn { body, .. } => {
                for b in body { walk(b, set, globals); }
            }
            Stmt::Switch { cases, default, .. } => {
                for (_, case_body) in cases {
                    for b in case_body { walk(b, set, globals); }
                }
                if let Some(default_body) = default {
                    for b in default_body { walk(b, set, globals); }
                }
            }
            _ => {}
        }
    }
    let mut set = BTreeSet::new();
    // Add parameters as locals FIRST
    for p in params {
        set.insert(p.clone());
    }
    for s in stmts { walk(s, &mut set, global_names); }
    set.into_iter().collect()
}

/// Analyze assignments to determine variable types (for struct instances)
/// Returns HashMap<var_name, (struct_type, size_in_bytes)>
pub fn analyze_var_types(
    stmts: &[Stmt], 
    locals: &[String],
    struct_registry: &std::collections::HashMap<String, crate::struct_layout::StructLayout>
) -> std::collections::HashMap<String, (String, usize)> {
    use crate::ast::Expr;
    
    fn walk_stmt(
        s: &Stmt,
        var_info: &mut std::collections::HashMap<String, (String, usize)>,
        locals: &[String],
        struct_registry: &std::collections::HashMap<String, crate::struct_layout::StructLayout>
    ) {
        match s {
            Stmt::Assign { target, value, .. } => {
                if let crate::ast::AssignTarget::Ident { name, .. } = target {
                    // Check if this is a local variable and if value is StructInit
                    if locals.contains(name) {
                        if let Expr::StructInit { struct_name, .. } = value {
                            // This variable is a struct instance
                            if let Some(layout) = struct_registry.get(struct_name) {
                                var_info.insert(name.clone(), (struct_name.clone(), layout.total_size));
                            }
                        }
                    }
                }
            }
            Stmt::Let { name, value, .. } => {
                if locals.contains(name) {
                    if let Expr::StructInit { struct_name, .. } = value {
                        if let Some(layout) = struct_registry.get(struct_name) {
                            var_info.insert(name.clone(), (struct_name.clone(), layout.total_size));
                        }
                    }
                }
            }
            Stmt::If { body, elifs, else_body, .. } => {
                for b in body { walk_stmt(b, var_info, locals, struct_registry); }
                for (_, elif_body) in elifs {
                    for b in elif_body { walk_stmt(b, var_info, locals, struct_registry); }
                }
                if let Some(else_stmts) = else_body {
                    for b in else_stmts { walk_stmt(b, var_info, locals, struct_registry); }
                }
            }
            Stmt::While { body, .. } | Stmt::For { body, .. } | Stmt::ForIn { body, .. } => {
                for b in body { walk_stmt(b, var_info, locals, struct_registry); }
            }
            Stmt::Switch { cases, default, .. } => {
                for (_, case_body) in cases {
                    for b in case_body { walk_stmt(b, var_info, locals, struct_registry); }
                }
                if let Some(default_body) = default {
                    for b in default_body { walk_stmt(b, var_info, locals, struct_registry); }
                }
            }
            _ => {}
        }
    }
    
    let mut var_info = std::collections::HashMap::new();
    for s in stmts {
        walk_stmt(s, &mut var_info, locals, struct_registry);
    }
    var_info
}

/// Loop context for break/continue handling
#[derive(Default, Clone)]
pub struct LoopCtx { 
    pub start: Option<String>, 
    pub end: Option<String> 
}

/// Function context with local variables
#[derive(Clone)]
pub struct FuncCtx { 
    pub locals: Vec<String>,
    pub frame_size: i32,
    // Maps variable name to (type_name, size_in_bytes)
    // For simple variables: ("", 2)
    // For struct instances: ("Point", 4) if Point has 2 fields
    pub var_info: std::collections::HashMap<String, (String, usize)>,
    // NEW: Track if we're in a struct method and which struct
    pub struct_type: Option<String>, // Some("Point") if in method, None if regular function
    // NEW: Track function parameters (in order) for correct stack offset calculation
    pub params: Vec<String>, // Parameter names in order (for correct stack positioning)
}

impl FuncCtx {
    pub fn offset_of(&self, name: &str) -> Option<i32> {
        // FIRST: Check if this is a parameter (they're always at fixed positions: 0,S, 2,S, 4,S, 6,S)
        for (i, param) in self.params.iter().enumerate() {
            if param.eq_ignore_ascii_case(name) {
                // Parameter found - return its fixed stack position
                return Some((i as i32) * 2); // Param 0 at 0,S, Param 1 at 2,S, etc.
            }
        }
        
        // If not a parameter, calculate offset for local variables
        // Local variables come AFTER parameters in the stack
        let param_space = (self.params.len() as i32) * 2; // Space taken by parameters
        let mut local_offset = param_space; // Start after parameters
        
        for var_name in &self.locals {
            if var_name.eq_ignore_ascii_case(name) {
                return Some(local_offset);
            }
            // Get size of this variable
            let size = self.var_info.get(var_name)
                .map(|(_, s)| *s as i32)
                .unwrap_or(2); // Default to 2 bytes for simple variables
            local_offset += size;
        }
        None
    }
    
    pub fn var_type(&self, name: &str) -> Option<&str> {
        self.var_info.get(name).map(|(t, _)| t.as_str())
    }
    
    pub fn current_function_struct_type(&self) -> Option<String> {
        self.struct_type.clone()
    }
}
