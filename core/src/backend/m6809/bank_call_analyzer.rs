// Cross-Bank Call Analyzer
// Traverses AST to detect function calls that cross bank boundaries

use crate::ast::{Expr, Function, Module, Stmt, Item};
use crate::backend::m6809::bank_wrappers::BankWrapperGenerator;

/// Traverse module AST and record all cross-bank function calls
pub fn analyze_cross_bank_calls(
    module: &Module,
    generator: &mut BankWrapperGenerator,
) {
    // Iterate over all function definitions
    for item in &module.items {
        if let Item::Function(func) = item {
            // Analyze this function's body for calls
            analyze_function_calls(func, generator);
        }
    }
}

/// Analyze a single function for cross-bank calls
fn analyze_function_calls(func: &Function, generator: &mut BankWrapperGenerator) {
    let caller_func = &func.name;
    
    // Traverse all statements in function body
    for stmt in &func.body {
        analyze_stmt_calls(stmt, caller_func, generator);
    }
}

/// Recursively analyze statements for function calls
fn analyze_stmt_calls(stmt: &Stmt, caller_func: &str, generator: &mut BankWrapperGenerator) {
    match stmt {
        Stmt::Expr(expr, _) => analyze_expr_calls(expr, caller_func, generator),
        
        Stmt::Assign { value, .. } => analyze_expr_calls(value, caller_func, generator),
        
        Stmt::If { cond, body, elifs, else_body, .. } => {
            analyze_expr_calls(cond, caller_func, generator);
            for s in body {
                analyze_stmt_calls(s, caller_func, generator);
            }
            for (elif_cond, elif_body) in elifs {
                analyze_expr_calls(elif_cond, caller_func, generator);
                for s in elif_body {
                    analyze_stmt_calls(s, caller_func, generator);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    analyze_stmt_calls(s, caller_func, generator);
                }
            }
        }
        
        Stmt::While { cond, body, .. } => {
            analyze_expr_calls(cond, caller_func, generator);
            for s in body {
                analyze_stmt_calls(s, caller_func, generator);
            }
        }
        
        Stmt::For { start, end, step, body, .. } => {
            analyze_expr_calls(start, caller_func, generator);
            analyze_expr_calls(end, caller_func, generator);
            if let Some(ref e) = step {
                analyze_expr_calls(e, caller_func, generator);
            }
            for s in body {
                analyze_stmt_calls(s, caller_func, generator);
            }
        }
        
        Stmt::Return(Some(expr), ..) => analyze_expr_calls(expr, caller_func, generator),
        
        _ => {} // Other statement types don't contain calls
    }
}

/// Recursively analyze expressions for function calls
fn analyze_expr_calls(expr: &Expr, caller_func: &str, generator: &mut BankWrapperGenerator) {
    match expr {
        Expr::Call(call_info) => {
            // This is a function call - check if it's cross-bank
            let callee_func = &call_info.name;
            
            // Check if both functions have bank assignments
            if let Some(_target_bank) = generator.is_cross_bank_call(caller_func, callee_func) {
                // Cross-bank call detected!
                generator.record_cross_bank_call(
                    caller_func.to_string(),
                    callee_func.to_string(),
                );
            }
            
            // Also analyze arguments (they might contain nested calls)
            for arg in &call_info.args {
                analyze_expr_calls(arg, caller_func, generator);
            }
        }
        
        Expr::MethodCall(method_call) => {
            // Analyze target expression
            analyze_expr_calls(&method_call.target, caller_func, generator);
            
            // Analyze arguments
            for arg in &method_call.args {
                analyze_expr_calls(arg, caller_func, generator);
            }
        }
        
        Expr::Binary { left, right, .. } => {
            analyze_expr_calls(left, caller_func, generator);
            analyze_expr_calls(right, caller_func, generator);
        }
        
        Expr::Compare { left, right, .. } => {
            analyze_expr_calls(left, caller_func, generator);
            analyze_expr_calls(right, caller_func, generator);
        }
        
        Expr::Logic { left, right, .. } => {
            analyze_expr_calls(left, caller_func, generator);
            analyze_expr_calls(right, caller_func, generator);
        }
        
        Expr::Not(operand) | Expr::BitNot(operand) => {
            analyze_expr_calls(operand, caller_func, generator);
        }
        
        Expr::List(elements) => {
            for elem in elements {
                analyze_expr_calls(elem, caller_func, generator);
            }
        }
        
        Expr::Index { target, index, .. } => {
            analyze_expr_calls(target, caller_func, generator);
            analyze_expr_calls(index, caller_func, generator);
        }
        
        Expr::FieldAccess { target, .. } => {
            analyze_expr_calls(target, caller_func, generator);
        }
        
        _ => {} // Literals, identifiers, etc. don't contain calls
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;
    
    // Helper to create minimal AST for testing
    fn create_test_function(name: &str, calls: Vec<&str>) -> Function {
        use crate::ast::{Stmt, Expr, CallInfo};
        
        let body: Vec<Stmt> = calls.iter().map(|callee| {
            Stmt::Expr(Expr::Call(CallInfo {
                name: callee.to_string(),
                args: vec![],
                source_line: 1,
                col: 0,
            }), 1)
        }).collect();
        
        Function {
            name: name.to_string(),
            params: vec![],
            body,
            line: 1,
            frame_group: None,
        }
    }
    
    #[test]
    fn test_detect_cross_bank_call() {
        let mut function_banks = HashMap::new();
        function_banks.insert("caller".to_string(), 0);
        function_banks.insert("target".to_string(), 31);
        
        let mut generator = BankWrapperGenerator::new(function_banks, 0x4000, 32);
        
        // Create function that calls target
        let func = create_test_function("caller", vec!["target"]);
        
        analyze_function_calls(&func, &mut generator);
        
        // Verify cross-bank call was recorded
        assert_eq!(generator.cross_bank_calls.len(), 1);
        assert_eq!(generator.cross_bank_calls[0].caller_func, "caller");
        assert_eq!(generator.cross_bank_calls[0].callee_func, "target");
    }
}
