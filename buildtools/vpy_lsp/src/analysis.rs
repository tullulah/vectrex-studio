//! Variable usage analysis over the `vpy_parser` AST: unused variables and
//! "could be const" hints.

use std::collections::HashMap;

use tower_lsp::lsp_types::{
    Diagnostic, DiagnosticSeverity, DiagnosticTag, NumberOrString, Position, Range,
};
use vpy_parser::{AssignTarget, CallInfo, Expr, IdentInfo, Item, Module, Stmt};

use crate::builtins::is_builtin_function;

/// How a variable is used throughout the code.
#[derive(Debug, Default, Clone)]
pub struct VariableUsage {
    pub declared: bool,
    pub initialized: bool,
    pub read_count: usize,
    pub write_count: usize,
    pub declaration_range: Option<Range>,
    pub last_write_range: Option<Range>,
    pub is_const: bool,
}

/// Usage of every variable declared in a module.
#[derive(Debug, Default)]
pub struct UsageAnalysis {
    pub variables: HashMap<String, VariableUsage>,
}

/// Analyze variable usage patterns in a module.
pub fn analyze_variable_usage(module: &Module) -> UsageAnalysis {
    let mut analysis = UsageAnalysis::default();

    // Collect declarations from top-level items.
    for item in &module.items {
        match item {
            Item::GlobalLet { name, value, source_line, .. } => {
                let usage = VariableUsage {
                    declared: true,
                    initialized: value != &Expr::Number(0), // Simplified check
                    write_count: 1,
                    declaration_range: Some(line_to_range(*source_line)),
                    ..Default::default()
                };
                analysis.variables.insert(name.clone(), usage);
                analyze_expr(value, &mut analysis);
            }
            Item::Const { name, value, source_line, .. } => {
                let usage = VariableUsage {
                    declared: true,
                    initialized: true,
                    write_count: 1,
                    is_const: true,
                    declaration_range: Some(line_to_range(*source_line)),
                    ..Default::default()
                };
                analysis.variables.insert(name.clone(), usage);
                analyze_expr(value, &mut analysis);
            }
            Item::Function(func) => analyze_statements(&func.body, &mut analysis),
            Item::ExprStatement(expr) => analyze_expr(expr, &mut analysis),
            _ => {}
        }
    }

    analysis
}

fn analyze_statements(stmts: &[Stmt], analysis: &mut UsageAnalysis) {
    for stmt in stmts {
        match stmt {
            Stmt::Assign { target, value, source_line } => {
                match target {
                    AssignTarget::Ident { name, .. } => {
                        if let Some(usage) = analysis.variables.get_mut(name) {
                            usage.write_count += 1;
                            usage.last_write_range = Some(line_to_range(*source_line));
                        }
                    }
                    AssignTarget::Index { target: t, index, .. } => {
                        // array[i] = value is a write to the array variable.
                        if let Expr::Ident(IdentInfo { name, .. }) = &**t {
                            if let Some(usage) = analysis.variables.get_mut(name) {
                                usage.write_count += 1;
                            }
                        }
                        analyze_expr(t, analysis);
                        analyze_expr(index, analysis);
                    }
                    AssignTarget::FieldAccess { target: t, .. } => analyze_expr(t, analysis),
                }
                analyze_expr(value, analysis);
            }
            Stmt::Let { name, value, source_line, .. } => {
                // Local variable declaration (inside a function).
                let usage = VariableUsage {
                    declared: true,
                    initialized: true,
                    write_count: 1,
                    declaration_range: Some(line_to_range(*source_line)),
                    ..Default::default()
                };
                analysis.variables.insert(name.clone(), usage);
                analyze_expr(value, analysis);
            }
            Stmt::CompoundAssign { target, value, .. } => {
                // x += y is both a read and a write.
                match target {
                    AssignTarget::Ident { name, .. } => {
                        if let Some(usage) = analysis.variables.get_mut(name) {
                            usage.read_count += 1;
                            usage.write_count += 1;
                        }
                    }
                    AssignTarget::Index { target: t, index, .. } => {
                        if let Expr::Ident(IdentInfo { name, .. }) = &**t {
                            if let Some(usage) = analysis.variables.get_mut(name) {
                                usage.read_count += 1;
                                usage.write_count += 1;
                            }
                        }
                        analyze_expr(t, analysis);
                        analyze_expr(index, analysis);
                    }
                    AssignTarget::FieldAccess { .. } => {}
                }
                analyze_expr(value, analysis);
            }
            Stmt::If { cond, body, elifs, else_body, .. } => {
                analyze_expr(cond, analysis);
                analyze_statements(body, analysis);
                for (elif_cond, elif_body) in elifs {
                    analyze_expr(elif_cond, analysis);
                    analyze_statements(elif_body, analysis);
                }
                if let Some(else_stmts) = else_body {
                    analyze_statements(else_stmts, analysis);
                }
            }
            Stmt::While { cond, body, .. } => {
                analyze_expr(cond, analysis);
                analyze_statements(body, analysis);
            }
            Stmt::For { start, end, step, body, .. } => {
                analyze_expr(start, analysis);
                analyze_expr(end, analysis);
                if let Some(step_expr) = step {
                    analyze_expr(step_expr, analysis);
                }
                analyze_statements(body, analysis);
            }
            Stmt::ForIn { iterable, body, .. } => {
                analyze_expr(iterable, analysis);
                analyze_statements(body, analysis);
            }
            Stmt::Switch { expr, cases, default, .. } => {
                analyze_expr(expr, analysis);
                for (case_expr, case_body) in cases {
                    analyze_expr(case_expr, analysis);
                    analyze_statements(case_body, analysis);
                }
                if let Some(default_body) = default {
                    analyze_statements(default_body, analysis);
                }
            }
            Stmt::Return(Some(expr), _) => analyze_expr(expr, analysis),
            Stmt::Expr(expr, _) => analyze_expr(expr, analysis),
            // Break, Continue, Pass, Return(None) don't reference variables.
            _ => {}
        }
    }
}

/// Count variable reads inside an expression.
fn analyze_expr(expr: &Expr, analysis: &mut UsageAnalysis) {
    match expr {
        Expr::Ident(IdentInfo { name, .. }) => {
            if let Some(usage) = analysis.variables.get_mut(name) {
                usage.read_count += 1;
            }
        }
        Expr::Call(CallInfo { args, .. }) => {
            for arg in args {
                analyze_expr(arg, analysis);
            }
        }
        Expr::MethodCall(method_call) => {
            analyze_expr(&method_call.target, analysis);
            for arg in &method_call.args {
                analyze_expr(arg, analysis);
            }
        }
        Expr::Binary { left, right, .. }
        | Expr::Compare { left, right, .. }
        | Expr::Logic { left, right, .. } => {
            analyze_expr(left, analysis);
            analyze_expr(right, analysis);
        }
        Expr::Not(inner) | Expr::BitNot(inner) => analyze_expr(inner, analysis),
        Expr::List(elements) => {
            for elem in elements {
                analyze_expr(elem, analysis);
            }
        }
        Expr::Index { target, index } => {
            analyze_expr(target, analysis);
            analyze_expr(index, analysis);
        }
        Expr::FieldAccess { target, .. } => analyze_expr(target, analysis),
        Expr::Number(_) | Expr::StringLit(_) | Expr::StructInit { .. } => {}
    }
}

/// Convert a 1-based source line into a whole-line LSP range.
pub fn line_to_range(line: usize) -> Range {
    let pos = Position {
        line: line.saturating_sub(1) as u32,
        character: 0,
    };
    Range {
        start: pos,
        end: Position {
            line: pos.line,
            character: 100, // Approximate end of line
        },
    }
}

/// Emit "unused-variable" warnings and "suggest-const" hints.
pub fn generate_usage_diagnostics(analysis: &UsageAnalysis, locale: &str, diags: &mut Vec<Diagnostic>) {
    for (name, usage) in &analysis.variables {
        // Builtins and constants are not user variables.
        if is_builtin_function(name) || usage.is_const {
            continue;
        }

        // Declared but never read. Names starting with '_' are intentionally unused.
        if usage.declared && usage.read_count == 0 && !name.starts_with('_') {
            if let Some(range) = &usage.declaration_range {
                let msg = if locale.starts_with("es") {
                    format!("Variable '{}' se declara pero nunca se usa", name)
                } else {
                    format!("Variable '{}' is declared but never used", name)
                };
                diags.push(Diagnostic {
                    range: *range,
                    severity: Some(DiagnosticSeverity::WARNING),
                    code: Some(NumberOrString::String("unused-variable".to_string())),
                    source: Some("vpy".to_string()),
                    message: msg,
                    tags: Some(vec![DiagnosticTag::UNNECESSARY]),
                    ..Default::default()
                });
            }
        }

        // Initialized once, never modified: could be const.
        if usage.initialized && usage.write_count == 1 && usage.read_count > 0 {
            if let Some(range) = &usage.declaration_range {
                let msg = if locale.starts_with("es") {
                    format!("Variable '{}' nunca cambia - considera 'const' para ahorrar RAM (2 bytes)", name)
                } else {
                    format!("Variable '{}' never changes - consider 'const' to save RAM (2 bytes)", name)
                };
                diags.push(Diagnostic {
                    range: *range,
                    severity: Some(DiagnosticSeverity::HINT),
                    code: Some(NumberOrString::String("suggest-const".to_string())),
                    source: Some("vpy".to_string()),
                    message: msg,
                    ..Default::default()
                });
            }
        }
    }

    eprintln!("[LSP] Generated {} usage diagnostics", diags.len());
}

/// Extract the quoted variable name from a usage diagnostic message, e.g.
/// "Variable 'num_locations' is declared but never used" -> "num_locations".
pub fn extract_var_name_from_diagnostic(message: &str) -> Option<String> {
    let start_idx = message.find('\'')?;
    let end_idx = message[start_idx + 1..].find('\'')?;
    Some(message[start_idx + 1..start_idx + 1 + end_idx].to_string())
}
