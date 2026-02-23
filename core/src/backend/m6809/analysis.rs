// Analysis - AST analysis functions for M6809 backend
use crate::ast::{BinOp, Expr, Function, Item, Module, Stmt};

use super::resolve_function_name;

macro_rules! check_depth {
    ($depth:expr, $max:expr, $context:expr) => {
        if $depth > $max {
            panic!("Maximum recursion depth ({}) exceeded in {}. Please simplify your code.", $max, $context);
        }
    };
}

#[derive(Default, Debug)]
pub struct RuntimeUsage {
    pub uses_mul: bool,
    pub uses_div: bool,
    pub uses_music: bool,
    pub uses_draw_vector: bool,
    pub uses_draw_vector_ex: bool,  // NEW: tracks DRAW_VECTOR_EX usage
    pub uses_draw_circle: bool,      // NEW: tracks DRAW_CIRCLE usage
    pub uses_show_level: bool,       // NEW: tracks SHOW_LEVEL usage
    pub uses_print_number: bool,     // BUGFIX: track PRINT_NUMBER usage
    pub needs_mul_helper: bool,
    pub needs_div_helper: bool,
    pub needs_tmp_left: bool,
    pub needs_tmp_right: bool,
    pub needs_tmp_ptr: bool,
    pub needs_line_vars: bool,
    pub needs_vcur_vars: bool,
    pub needs_vectorlist_runtime: bool,
    pub wrappers_used: std::collections::HashSet<String>,
}

pub fn expr_has_trig(e: &Expr) -> bool {
    expr_has_trig_depth(e, 0)
}

pub fn expr_has_trig_depth(e: &Expr, depth: usize) -> bool {
    check_depth!(depth, 500, "expr_has_trig");
    match e {
        Expr::Call(ci) => {
            let u = ci.name.to_ascii_lowercase();
            u == "sin" || u == "cos" || u == "tan" || u == "math.sin" || u == "math.cos" || u == "math.tan"
        }
        Expr::MethodCall(mc) => {
            // Check target and args for trig
            expr_has_trig_depth(&mc.target, depth + 1) || mc.args.iter().any(|a| expr_has_trig_depth(a, depth + 1))
        }
        Expr::Binary { left, right, .. } | Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => 
            expr_has_trig_depth(left, depth + 1) || expr_has_trig_depth(right, depth + 1),
        Expr::Not(inner) | Expr::BitNot(inner) => expr_has_trig_depth(inner, depth + 1),
        Expr::List(elements) => elements.iter().any(|e| expr_has_trig_depth(e, depth + 1)),
        Expr::Index { target, index } => expr_has_trig_depth(target, depth + 1) || expr_has_trig_depth(index, depth + 1),
        _ => false,
    }
}

pub fn module_uses_trig(module: &Module) -> bool {
    for item in &module.items {
        if let Item::Function(f) = item {
            for s in &f.body { if stmt_has_trig(s) { return true; } }
        } else if let Item::ExprStatement(expr) = item {
            if expr_has_trig(expr) { return true; }
        }
    }
    false
}

pub fn stmt_has_trig(s: &Stmt) -> bool {
    stmt_has_trig_depth(s, 0)
}

pub fn stmt_has_trig_depth(s: &Stmt, depth: usize) -> bool {
    check_depth!(depth, 500, "stmt_has_trig");
    match s {
        Stmt::Assign { value, .. } => expr_has_trig_depth(value, depth + 1),
        Stmt::Let { value, .. } => expr_has_trig_depth(value, depth + 1),
        Stmt::Expr(e, _) => expr_has_trig_depth(e, depth + 1),
    Stmt::For { start, end, step, body, .. } => expr_has_trig_depth(start, depth + 1) || expr_has_trig_depth(end, depth + 1) || step.as_ref().map(|e| expr_has_trig_depth(e, depth + 1)).unwrap_or(false) || body.iter().any(|s| stmt_has_trig_depth(s, depth + 1)),
        Stmt::ForIn { iterable, body, .. } => expr_has_trig_depth(iterable, depth + 1) || body.iter().any(|s| stmt_has_trig_depth(s, depth + 1)),
        Stmt::While { cond, body, .. } => expr_has_trig_depth(cond, depth + 1) || body.iter().any(|s| stmt_has_trig_depth(s, depth + 1)),
        Stmt::If { cond, body, elifs, else_body, .. } => expr_has_trig_depth(cond, depth + 1) || body.iter().any(|s| stmt_has_trig_depth(s, depth + 1)) || elifs.iter().any(|(c,b)| expr_has_trig_depth(c, depth + 1) || b.iter().any(|s| stmt_has_trig_depth(s, depth + 1))) || else_body.as_ref().map(|eb| eb.iter().any(|s| stmt_has_trig_depth(s, depth + 1))).unwrap_or(false),
        Stmt::Return(o, _) => o.as_ref().map(|e| expr_has_trig_depth(e, depth + 1)).unwrap_or(false),
        Stmt::Switch { expr, cases, default, .. } => expr_has_trig(expr) || cases.iter().any(|(ce, cb)| expr_has_trig(ce) || cb.iter().any(stmt_has_trig)) || default.as_ref().map(|db| db.iter().any(stmt_has_trig)).unwrap_or(false),
        Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => false,
        Stmt::CompoundAssign { .. } => panic!("CompoundAssign should be transformed away before stmt_has_trig"),
    }
}

pub fn compute_max_args_used(module: &Module) -> usize {
    let mut maxa = 0usize;
    for item in &module.items {
        if let Item::Function(f) = item {
            // Count function parameters (they will need VAR_ARG slots)
            maxa = maxa.max(f.params.len());
            // Count arguments in function body calls
            for s in &f.body { maxa = maxa.max(scan_stmt_args(s)); }
        } else if let Item::ExprStatement(expr) = item {
            maxa = maxa.max(scan_expr_args(expr));
        }
    }
    maxa
}

pub fn scan_stmt_args(s: &Stmt) -> usize {
    match s {
        Stmt::Assign { value, .. } | Stmt::Let { value, .. } | Stmt::Expr(value, _) => scan_expr_args(value),
        Stmt::For { start, end, step, body, .. } => {
            let mut m = scan_expr_args(start).max(scan_expr_args(end));
            if let Some(se) = step { m = m.max(scan_expr_args(se)); }
            for st in body { m = m.max(scan_stmt_args(st)); }
            m
        }
        Stmt::ForIn { iterable, body, .. } => {
            let mut m = scan_expr_args(iterable);
            for st in body { m = m.max(scan_stmt_args(st)); }
            m
        }
        Stmt::While { cond, body, .. } => {
            let mut m = scan_expr_args(cond);
            for st in body { m = m.max(scan_stmt_args(st)); }
            m
        }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            let mut m = scan_expr_args(cond);
            for st in body { m = m.max(scan_stmt_args(st)); }
            for (c, b) in elifs { m = m.max(scan_expr_args(c)); for st in b { m = m.max(scan_stmt_args(st)); } }
            if let Some(eb) = else_body { for st in eb { m = m.max(scan_stmt_args(st)); } }
            m
        }
        Stmt::Return(o, _) => o.as_ref().map(scan_expr_args).unwrap_or(0),
        Stmt::Switch { expr, cases, default, .. } => {
            let mut m = scan_expr_args(expr);
            for (ce, cb) in cases { m = m.max(scan_expr_args(ce)); for st in cb { m = m.max(scan_stmt_args(st)); } }
            if let Some(db) = default { for st in db { m = m.max(scan_stmt_args(st)); } }
            m
        }
        Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => 0,
        Stmt::CompoundAssign { .. } => panic!("CompoundAssign should be transformed away before scan_stmt_args"),
    }
}

pub fn scan_expr_args(e: &Expr) -> usize {
    match e {
        Expr::Call(ci) => {
            // Check if this call can be optimized inline (no VAR_ARG usage)
            let up = ci.name.to_ascii_uppercase();
            
            // DRAW_LINE with all constants doesn't use VAR_ARG (optimized inline)
            if up == "DRAW_LINE" && ci.args.len() == 5 && 
               ci.args.iter().all(|a| matches!(a, Expr::Number(_))) {
                // This call will be optimized inline - doesn't use VAR_ARG
                return ci.args.iter().map(scan_expr_args).max().unwrap_or(0);
            }
            
            // Struct constructors pass self as ARG0 + N args → needs N+1 slots
            // Be conservative: assume any call MIGHT be a constructor → count args + 1
            // This ensures we allocate enough VAR_ARG slots for constructors
            let max_slots_needed = (ci.args.len() + 1).min(6);
            max_slots_needed.max(ci.args.iter().map(scan_expr_args).max().unwrap_or(0))
        },
        Expr::MethodCall(mc) => {
            // Method calls: self + args (self is ARG0, args are ARG1+)
            // Total = 1 (self) + args.len(), capped at 5
            let total_args = 1 + mc.args.len();
            total_args.min(5).max(
                scan_expr_args(&mc.target).max(
                    mc.args.iter().map(scan_expr_args).max().unwrap_or(0)
                )
            )
        },
        Expr::Binary { left, right, .. } | Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => scan_expr_args(left).max(scan_expr_args(right)),
        Expr::Not(inner) | Expr::BitNot(inner) => scan_expr_args(inner),
        Expr::List(elements) => elements.iter().map(scan_expr_args).max().unwrap_or(0),
        Expr::Index { target, index } => scan_expr_args(target).max(scan_expr_args(index)),
        _ => 0,
    }
}

use std::collections::HashSet;

pub fn analyze_runtime_usage(module: &Module) -> RuntimeUsage {
    let mut usage = RuntimeUsage::default();
    for item in &module.items {
        if let Item::Function(f) = item {
            for s in &f.body { scan_stmt_runtime(s, &mut usage); }
        } else if let Item::ExprStatement(expr) = item {
            scan_expr_runtime(expr, &mut usage);
        }
    }
    // Derive grouped variable needs from wrappers
    if usage.wrappers_used.contains("DRAW_LINE_WRAPPER") || usage.wrappers_used.contains("VECTREX_DRAW_VL") || usage.wrappers_used.contains("VECTREX_DRAW_TO") {
        usage.needs_line_vars = true;
    }
    if usage.wrappers_used.contains("VECTREX_MOVE_TO") || usage.wrappers_used.contains("VECTREX_DRAW_TO") {
        usage.needs_vcur_vars = true;
    }
    usage
}

pub fn scan_stmt_runtime(s: &Stmt, usage: &mut RuntimeUsage) {
    match s {
        Stmt::Assign { value, .. } => { usage.needs_tmp_ptr = true; scan_expr_runtime(value, usage); },
        Stmt::Let { value, .. } => scan_expr_runtime(value, usage),
        Stmt::Expr(value, _) => scan_expr_runtime(value, usage),
        Stmt::For { start, end, step, body, .. } => {
            scan_expr_runtime(start, usage);
            scan_expr_runtime(end, usage);
            if let Some(se) = step { scan_expr_runtime(se, usage); }
            for st in body { scan_stmt_runtime(st, usage); }
        }
        Stmt::ForIn { iterable, body, .. } => {
            usage.needs_tmp_ptr = true;  // Need TMPPTR for array pointer
            usage.needs_tmp_left = true; // Need TMPLEFT for element count
            scan_expr_runtime(iterable, usage);
            for st in body { scan_stmt_runtime(st, usage); }
        }
        Stmt::While { cond, body, .. } => { scan_expr_runtime(cond, usage); for st in body { scan_stmt_runtime(st, usage); } }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            scan_expr_runtime(cond, usage);
            for st in body { scan_stmt_runtime(st, usage); }
            for (c, b) in elifs { scan_expr_runtime(c, usage); for st in b { scan_stmt_runtime(st, usage); } }
            if let Some(eb) = else_body { for st in eb { scan_stmt_runtime(st, usage); } }
        }
        Stmt::Return(o, _) => { if let Some(e) = o { scan_expr_runtime(e, usage); } }
        Stmt::Switch { expr, cases, default, .. } => {
            scan_expr_runtime(expr, usage);
            for (ce, cb) in cases { scan_expr_runtime(ce, usage); for st in cb { scan_stmt_runtime(st, usage); } }
            if let Some(db) = default { for st in db { scan_stmt_runtime(st, usage); } }
            usage.needs_tmp_left = true; usage.needs_tmp_right = true; // switch lowering uses TMPLEFT
        }
        Stmt::Break { .. } | Stmt::Continue { .. } | Stmt::Pass { .. } => {},
        Stmt::CompoundAssign { .. } => panic!("CompoundAssign should be transformed away before scan_stmt_runtime"),
    }
}

pub fn scan_expr_runtime(e: &Expr, usage: &mut RuntimeUsage) {
    match e {
        Expr::Binary { op, left, right } => {
            // Only mark if not optimized away (non power-of-two cases handled later)
            match op {
                BinOp::Mul => { usage.needs_mul_helper = true; }
                BinOp::Div | BinOp::Mod => { usage.needs_div_helper = true; }
                _ => {}
            }
            usage.needs_tmp_left = true; usage.needs_tmp_right = true; // general binary op temps
            scan_expr_runtime(left, usage);
            scan_expr_runtime(right, usage);
        }
        Expr::Call(ci) => { 
            // Track wrapper usage (normalize like emit_builtin_call)
            let up = ci.name.to_ascii_uppercase();
            let resolved = resolve_function_name(&up);
            if let Some(r) = resolved {
                // Always use wrapper (no inline optimization)
                usage.wrappers_used.insert(r);
            }
            // Check if this function needs vectorlist runtime
            if up == "VECTREX_DRAW_VECTORLIST" || up == "DRAW_VECTORLIST" {
                usage.needs_vectorlist_runtime = true;
            }
            // DRAW_LINE: mark wrapper as needed if:
            // 1. Not all args are constants (can't optimize inline), OR
            // 2. Constants have deltas > ±127 (requires segmentation)
            if up == "DRAW_LINE" {
                let mut needs_wrapper = false;
                
                // Check if this call can be optimized inline (all 5 args are constants)
                if ci.args.len() == 5 && ci.args.iter().all(|a| matches!(a, Expr::Number(_))) {
                    // All constants - check if deltas require segmentation
                    if let (Expr::Number(x0), Expr::Number(y0), Expr::Number(x1), Expr::Number(y1), _) = 
                        (&ci.args[0], &ci.args[1], &ci.args[2], &ci.args[3], &ci.args[4]) {
                        let dx = (x1 - x0) as i32;
                        let dy = (y1 - y0) as i32;
                        
                        // If deltas require segmentation (> ±127), need wrapper
                        if dy > 127 || dy < -128 || dx > 127 || dx < -128 {
                            needs_wrapper = true;
                        }
                    }
                } else {
                    // Not all constants - can't optimize inline
                    needs_wrapper = true;
                }
                
                if needs_wrapper {
                    usage.wrappers_used.insert("DRAW_LINE_WRAPPER".to_string());
                }
            }
            // Music/SFX system: track runtime helpers needed
            if up == "PLAY_MUSIC" {
                usage.wrappers_used.insert("PLAY_MUSIC_RUNTIME".to_string());
            }
            if up == "PLAY_SFX" {
                usage.wrappers_used.insert("PLAY_SFX_RUNTIME".to_string());
            }
            if up == "STOP_MUSIC" {
                usage.wrappers_used.insert("STOP_MUSIC_RUNTIME".to_string());
            }
            if up == "MUSIC_UPDATE" {
                usage.wrappers_used.insert("UPDATE_MUSIC_PSG".to_string());
            }
            // Level system: track level loading helpers
            if up == "LOAD_LEVEL" {
                usage.wrappers_used.insert("LOAD_LEVEL_RUNTIME".to_string());
            }
            if up == "GET_OBJECT_COUNT" {
                usage.wrappers_used.insert("GET_OBJECT_COUNT_RUNTIME".to_string());
            }
            if up == "GET_OBJECT_PTR" {
                usage.wrappers_used.insert("GET_OBJECT_PTR_RUNTIME".to_string());
            }
            if up == "GET_LEVEL_BOUNDS" {
                usage.wrappers_used.insert("GET_LEVEL_BOUNDS_RUNTIME".to_string());
            }
            if up == "SHOW_LEVEL" {
                eprintln!("[DEBUG] Found SHOW_LEVEL call at analysis");
                usage.wrappers_used.insert("SHOW_LEVEL_RUNTIME".to_string());
                usage.uses_show_level = true;  // NEW: Mark for variable allocation
            }
            if up == "UPDATE_LEVEL" {
                usage.wrappers_used.insert("UPDATE_LEVEL_RUNTIME".to_string());
            }
            // DRAW_VECTOR_EX: needs DRAW_VEC_X/Y and MIRROR_X/Y variables
            if up == "DRAW_VECTOR_EX" {
                usage.uses_draw_vector_ex = true;
            }
            // DRAW_VECTOR: basic vector drawing (needs Draw_Sync_List)
            if up == "DRAW_VECTOR" {
                usage.uses_draw_vector = true;
            }
            // DRAW_CIRCLE: needs DRAW_CIRCLE_* variables
            if up == "DRAW_CIRCLE" {
                usage.uses_draw_circle = true;
                usage.wrappers_used.insert("DRAW_CIRCLE_RUNTIME".to_string());
            }
            // PRINT_NUMBER: needs NUM_STR buffer
            if up == "PRINT_NUMBER" {
                usage.uses_print_number = true;
            }
            for a in &ci.args { scan_expr_runtime(a, usage); }
        }
        Expr::MethodCall(mc) => {
            // Method calls don't use wrappers (user-defined functions)
            scan_expr_runtime(&mc.target, usage);
            for a in &mc.args { scan_expr_runtime(a, usage); }
        }
        Expr::Compare { left, right, .. } | Expr::Logic { left, right, .. } => {
            scan_expr_runtime(left, usage);
            scan_expr_runtime(right, usage);
            usage.needs_tmp_left = true; usage.needs_tmp_right = true;
        }
        Expr::Not(inner) | Expr::BitNot(inner) => scan_expr_runtime(inner, usage),
        Expr::List(elements) => {
            for elem in elements {
                scan_expr_runtime(elem, usage);
            }
            // Array literal creation might need temporary storage
            usage.needs_tmp_ptr = true;
        }
        Expr::Index { target, index } => {
            scan_expr_runtime(target, usage);
            scan_expr_runtime(index, usage);
            usage.needs_tmp_ptr = true; // Array indexing needs address computation
        }
        _ => {}
    }
}

// emit_function: outputs code for a function.
