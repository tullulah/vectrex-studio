// Call Graph Analysis for Automatic Bank Switching
// Analyzes which functions call which, estimates sizes, and calculates frequencies

use crate::ast::*;
use std::collections::{HashMap, HashSet};

/// Node in the call graph (represents a function)
#[derive(Debug, Clone)]
pub struct FunctionNode {
    /// Function name
    pub name: String,
    /// Estimated size in bytes (ASM)
    pub size_bytes: usize,
    /// Is this a critical function (main, interrupt handler)?
    pub is_critical: bool,
    /// Call frequency (estimated calls per second)
    pub call_frequency: u32,
}

/// Edge in the call graph (represents a function call)
#[derive(Debug, Clone)]
pub struct CallEdge {
    /// Caller function name
    pub from: String,
    /// Callee function name
    pub to: String,
    /// Call frequency (how many times per invocation)
    pub frequency: u32,
}

/// Complete call graph
#[derive(Debug, Clone)]
pub struct CallGraph {
    /// All function nodes
    pub nodes: HashMap<String, FunctionNode>,
    /// All call edges
    pub edges: Vec<CallEdge>,
}

impl CallGraph {
    pub fn new() -> Self {
        CallGraph {
            nodes: HashMap::new(),
            edges: Vec::new(),
        }
    }
    
    /// Add a function node
    pub fn add_node(&mut self, node: FunctionNode) {
        self.nodes.insert(node.name.clone(), node);
    }
    
    /// Add a call edge
    pub fn add_edge(&mut self, edge: CallEdge) {
        self.edges.push(edge);
    }
    
    /// Get functions that are called by a specific function
    pub fn callees(&self, func: &str) -> Vec<String> {
        self.edges.iter()
            .filter(|e| e.from == func)
            .map(|e| e.to.clone())
            .collect()
    }
    
    /// Get functions that call a specific function
    pub fn callers(&self, func: &str) -> Vec<String> {
        self.edges.iter()
            .filter(|e| e.to == func)
            .map(|e| e.from.clone())
            .collect()
    }
    
    /// Calculate call frequencies starting from main (propagation)
    pub fn calculate_frequencies(&mut self) {
        // Start with main() having frequency 1
        if let Some(main_node) = self.nodes.get_mut("main") {
            main_node.call_frequency = 1;
        }
        
        // Propagate frequencies through call graph
        // Simple algorithm: BFS from main, multiply frequencies
        let mut visited = HashSet::new();
        let mut queue = vec!["main".to_string()];
        
        while let Some(func) = queue.pop() {
            if visited.contains(&func) {
                continue;
            }
            visited.insert(func.clone());
            
            let caller_freq = self.nodes.get(&func)
                .map(|n| n.call_frequency)
                .unwrap_or(0);
            
            // Propagate to callees
            for edge in &self.edges.clone() {
                if edge.from == func {
                    if let Some(callee) = self.nodes.get_mut(&edge.to) {
                        // Frequency = caller_freq * edge.frequency
                        callee.call_frequency += caller_freq * edge.frequency;
                        queue.push(edge.to.clone());
                    }
                }
            }
        }
    }
    
    /// Find "hot" functions (called frequently)
    pub fn hot_functions(&self, threshold: u32) -> Vec<String> {
        self.nodes.iter()
            .filter(|(_, node)| node.call_frequency >= threshold)
            .map(|(name, _)| name.clone())
            .collect()
    }
    
    /// Total size of all functions
    pub fn total_size(&self) -> usize {
        self.nodes.values().map(|n| n.size_bytes).sum()
    }
}

/// Build call graph from AST module
pub fn build_call_graph(module: &Module) -> CallGraph {
    let mut graph = CallGraph::new();
    
    // Phase 1: Create nodes for all functions
    for item in &module.items {
        if let Item::Function(func) = item {
            let is_critical = is_critical_function(&func.name);
            let size_bytes = estimate_function_size(func);
            
            graph.add_node(FunctionNode {
                name: func.name.clone(),
                size_bytes,
                is_critical,
                call_frequency: 0, // Will be calculated later
            });
        }
    }
    
    // Phase 2: Create edges for all function calls
    for item in &module.items {
        if let Item::Function(func) = item {
            let calls = find_function_calls(&func.body);
            for call in calls {
                graph.add_edge(CallEdge {
                    from: func.name.clone(),
                    to: call.target,
                    frequency: call.frequency,
                });
            }
        }
    }
    
    // Phase 3: Calculate call frequencies (propagation from main)
    graph.calculate_frequencies();
    
    graph
}

/// Check if a function is critical (must be in fixed bank)
/// In sequential model, NOTHING is critical - all code goes to Bank #0
/// Return false always for sequential model (no critical functions)
fn is_critical_function(_name: &str) -> bool {
    // Sequential Model (2025-01-12):
    // - NO functions are "critical"
    // - ALL code goes to Bank #0 and linker distributes as needed
    // - Returning false allows sequential bank assignment
    false
}

/// Estimate function size in bytes (rough approximation)
fn estimate_function_size(func: &Function) -> usize {
    // Conservative estimate: 50 bytes per statement + 100 bytes overhead
    // This accounts for:
    // - Vector/graphics data (large constant arrays)
    // - String literals (FCC directives)
    // - Complex expressions (multiple M6809 instructions per statement)
    // Better to overestimate and use more banks than underestimate and overflow
    let stmt_count = count_statements(&func.body);
    100 + (stmt_count * 50)
}

/// Count statements recursively
fn count_statements(stmts: &[Stmt]) -> usize {
    let mut count = 0;
    for stmt in stmts {
        count += 1;
        match stmt {
            Stmt::If { body, elifs, else_body, .. } => {
                count += count_statements(body);
                for (_, elif_body) in elifs {
                    count += count_statements(elif_body);
                }
                if let Some(else_stmts) = else_body {
                    count += count_statements(else_stmts);
                }
            }
            Stmt::While { body, .. } => {
                count += count_statements(body);
            }
            Stmt::For { body, .. } => {
                count += count_statements(body);
            }
            _ => {}
        }
    }
    count
}

/// Information about a function call found in code
#[derive(Debug, Clone)]
struct FunctionCall {
    target: String,
    frequency: u32, // Estimated calls per invocation
}

/// Find all function calls in statement list
fn find_function_calls(stmts: &[Stmt]) -> Vec<FunctionCall> {
    let mut calls = Vec::new();
    for stmt in stmts {
        find_calls_in_stmt(stmt, &mut calls, 1);
    }
    calls
}

/// Find function calls in a single statement (recursive)
fn find_calls_in_stmt(stmt: &Stmt, calls: &mut Vec<FunctionCall>, multiplier: u32) {
    match stmt {
        Stmt::Expr(expr, _) => {
            find_calls_in_expr(expr, calls, multiplier);
        }
        Stmt::Let { value, .. } => {
            find_calls_in_expr(value, calls, multiplier);
        }
        Stmt::Assign { value, .. } => {
            find_calls_in_expr(value, calls, multiplier);
        }
        Stmt::If { cond, body, elifs, else_body, .. } => {
            find_calls_in_expr(cond, calls, multiplier);
            for s in body {
                find_calls_in_stmt(s, calls, multiplier);
            }
            for (elif_cond, elif_body) in elifs {
                find_calls_in_expr(elif_cond, calls, multiplier);
                for s in elif_body {
                    find_calls_in_stmt(s, calls, multiplier);
                }
            }
            if let Some(else_stmts) = else_body {
                for s in else_stmts {
                    find_calls_in_stmt(s, calls, multiplier);
                }
            }
        }
        Stmt::While { cond, body, .. } => {
            find_calls_in_expr(cond, calls, multiplier * 10); // Assume 10 iterations
            for s in body {
                find_calls_in_stmt(s, calls, multiplier * 10);
            }
        }
        Stmt::For { body, .. } => {
            // Assume 10 iterations for loops
            for s in body {
                find_calls_in_stmt(s, calls, multiplier * 10);
            }
        }
        Stmt::Return(value, _) => {
            if let Some(expr) = value {
                find_calls_in_expr(expr, calls, multiplier);
            }
        }
        _ => {}
    }
}

/// Find function calls in an expression
fn find_calls_in_expr(expr: &Expr, calls: &mut Vec<FunctionCall>, multiplier: u32) {
    match expr {
        Expr::Call(call_info) => {
            // Check if it's a user function (not builtin)
            if !is_builtin(&call_info.name) {
                calls.push(FunctionCall {
                    target: call_info.name.clone(),
                    frequency: multiplier,
                });
            }
            // Also check call arguments
            for arg in &call_info.args {
                find_calls_in_expr(arg, calls, multiplier);
            }
        }
        Expr::Binary { left, right, .. } => {
            find_calls_in_expr(left, calls, multiplier);
            find_calls_in_expr(right, calls, multiplier);
        }
        Expr::Not(operand) | Expr::BitNot(operand) => {
            find_calls_in_expr(operand, calls, multiplier);
        }
        Expr::Index { target, index, .. } => {
            find_calls_in_expr(target, calls, multiplier);
            find_calls_in_expr(index, calls, multiplier);
        }
        Expr::List(elements) => {
            for elem in elements {
                find_calls_in_expr(elem, calls, multiplier);
            }
        }
        Expr::FieldAccess { target, .. } => {
            find_calls_in_expr(target, calls, multiplier);
        }
        _ => {}
    }
}

/// Check if a function name is a builtin
fn is_builtin(name: &str) -> bool {
    matches!(name,
        "WAIT_RECAL" | "SET_ORIGIN" | "MUSIC_UPDATE" | "STOP_MUSIC" |
        "MOVE" | "PRINT_TEXT" | "DRAW_TO" | "DRAW_LINE" | "DEBUG_PRINT" |
        "DEBUG_PRINT_LABELED" | "DEBUG_PRINT_STR" | "DRAW_VECTOR" |
        "PLAY_MUSIC" | "PLAY_SFX" | "DRAW_VECTOR_LIST" | "DRAW_VL" |
        "FRAME_BEGIN" | "ABS" | "LEN" | "ASM" | "SET_INTENSITY" |
        "J1_X" | "J1_Y" | "J1_BUTTON_1" | "J1_BUTTON_2" | "J1_BUTTON_3" | "J1_BUTTON_4" |
        "LOAD_LEVEL" | "SHOW_LEVEL" | "UPDATE_LEVEL" | "GET_LEVEL_BOUNDS" |
        "DRAW_VECTOR_EX" | "SFX_UPDATE" | "SET_TEXT_SIZE" | "PRINT_NUMBER" |
        "RAND" | "RAND_RANGE" | "BEEP" | "UPDATE_BUTTONS"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_empty_graph() {
        let graph = CallGraph::new();
        assert_eq!(graph.nodes.len(), 0);
        assert_eq!(graph.edges.len(), 0);
    }
    
    #[test]
    fn test_add_node() {
        let mut graph = CallGraph::new();
        graph.add_node(FunctionNode {
            name: "test".to_string(),
            size_bytes: 100,
            is_critical: false,
            call_frequency: 0,
        });
        assert_eq!(graph.nodes.len(), 1);
        assert!(graph.nodes.contains_key("test"));
    }
    
    #[test]
    fn test_add_edge() {
        let mut graph = CallGraph::new();
        graph.add_edge(CallEdge {
            from: "main".to_string(),
            to: "helper".to_string(),
            frequency: 1,
        });
        assert_eq!(graph.edges.len(), 1);
    }
}
