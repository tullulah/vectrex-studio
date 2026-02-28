//! Call graph analysis for determining function dependencies
//!
//! Builds a call graph to understand function call patterns
//! for optimal bank allocation
//!
//! ## Dependency-Aware Clustering (2026-01-20)
//! - Tracks assets used by each function (DRAW_VECTOR, PLAY_MUSIC)
//! - Groups related functions + assets into clusters
//! - Minimizes cross-bank calls for better performance

use std::collections::{HashMap, HashSet};
use vpy_parser::{Module, Item, Function, Stmt, Expr};

/// Node in the call graph (represents a function)
#[derive(Debug, Clone)]
pub struct FunctionNode {
    /// Function name
    pub name: String,
    /// Estimated size in bytes (ASM code)
    pub size_bytes: usize,
    /// Is this a critical function (main, loop, interrupt handler)?
    pub is_critical: bool,
    /// Assets used by this function (vector/music names)
    pub assets_used: HashSet<String>,
}

/// Edge in the call graph (represents a function call)
#[derive(Debug, Clone)]
pub struct CallEdge {
    /// Caller function name
    pub from: String,
    /// Callee function name
    pub to: String,
}

impl CallEdge {
    /// Create a new call edge
    pub fn new(from: String, to: String) -> Self {
        CallEdge { from, to }
    }
}

/// A cluster of related functions and their assets
#[derive(Debug, Clone)]
pub struct FunctionCluster {
    /// Cluster ID
    pub id: usize,
    /// Functions in this cluster
    pub functions: HashSet<String>,
    /// Assets used by functions in this cluster
    pub assets: HashSet<String>,
    /// Total estimated size (functions + assets)
    pub total_size: usize,
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
    
    /// Build call graph from unified module
    pub fn from_module(module: &Module) -> Self {
        let mut graph = CallGraph::new();

        // Add all functions as nodes
        for item in &module.items {
            if let Item::Function(func) = item {
                let size_estimate = estimate_function_size(func);
                let is_critical = func.name == "main" || func.name == "loop";
                let assets_used = find_assets_used(&func.body);

                graph.add_node(FunctionNode {
                    name: func.name.clone(),
                    size_bytes: size_estimate,
                    is_critical,
                    assets_used,
                });
            }
        }
        
        // Analyze function calls to build edges
        for item in &module.items {
            if let Item::Function(func) = item {
                let callees = find_function_calls(&func.body);
                for callee in callees {
                    graph.add_edge(CallEdge {
                        from: func.name.clone(),
                        to: callee,
                    });
                }
            }
        }
        
        graph
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
    
    /// Build dependency clusters using Union-Find algorithm
    /// 
    /// Groups functions that:
    /// 1. Call each other (directly or transitively)
    /// 2. Share common assets
    /// 
    /// Returns clusters sorted by size (largest first)
    pub fn build_clusters(&self, asset_sizes: &HashMap<String, usize>) -> Vec<FunctionCluster> {
        // Union-Find for clustering
        let func_names: Vec<&String> = self.nodes.keys().collect();
        let n = func_names.len();
        
        if n == 0 {
            return Vec::new();
        }
        
        // Create name -> index mapping
        let name_to_idx: HashMap<&String, usize> = func_names.iter()
            .enumerate()
            .map(|(i, name)| (*name, i))
            .collect();
        
        // Union-Find parent array
        let mut parent: Vec<usize> = (0..n).collect();
        
        fn find(parent: &mut [usize], i: usize) -> usize {
            if parent[i] != i {
                parent[i] = find(parent, parent[i]); // Path compression
            }
            parent[i]
        }
        
        fn union(parent: &mut [usize], i: usize, j: usize) {
            let pi = find(parent, i);
            let pj = find(parent, j);
            if pi != pj {
                parent[pi] = pj;
            }
        }
        
        // Union functions that call each other
        for edge in &self.edges {
            if let (Some(&from_idx), Some(&to_idx)) = (name_to_idx.get(&edge.from), name_to_idx.get(&edge.to)) {
                union(&mut parent, from_idx, to_idx);
            }
        }
        
        // Union functions that share assets
        let mut asset_to_funcs: HashMap<&String, Vec<usize>> = HashMap::new();
        for (name, node) in &self.nodes {
            if let Some(&idx) = name_to_idx.get(name) {
                for asset in &node.assets_used {
                    asset_to_funcs.entry(asset).or_default().push(idx);
                }
            }
        }
        
        for funcs in asset_to_funcs.values() {
            if funcs.len() > 1 {
                for i in 1..funcs.len() {
                    union(&mut parent, funcs[0], funcs[i]);
                }
            }
        }
        
        // Build clusters from Union-Find result
        let mut cluster_members: HashMap<usize, HashSet<String>> = HashMap::new();
        for (i, name) in func_names.iter().enumerate() {
            let root = find(&mut parent, i);
            cluster_members.entry(root).or_default().insert((*name).clone());
        }
        
        // Create FunctionCluster objects
        let mut clusters: Vec<FunctionCluster> = cluster_members.into_iter()
            .enumerate()
            .map(|(id, (_, functions))| {
                // Collect assets used by all functions in cluster
                let mut assets = HashSet::new();
                let mut func_size = 0;
                
                for func_name in &functions {
                    if let Some(node) = self.nodes.get(func_name) {
                        func_size += node.size_bytes;
                        for asset in &node.assets_used {
                            assets.insert(asset.clone());
                        }
                    }
                }
                
                // Calculate total size (functions + assets)
                let asset_size: usize = assets.iter()
                    .map(|a| asset_sizes.get(a).copied().unwrap_or(500)) // Default 500 bytes per asset
                    .sum();
                
                FunctionCluster {
                    id,
                    functions,
                    assets,
                    total_size: func_size + asset_size,
                }
            })
            .collect();
        
        // Sort clusters by total size (largest first) - helps pack efficiently
        clusters.sort_by(|a, b| b.total_size.cmp(&a.total_size));
        
        clusters
    }
    
    /// Get all assets used across all functions
    pub fn all_assets(&self) -> HashSet<String> {
        let mut all = HashSet::new();
        for node in self.nodes.values() {
            for asset in &node.assets_used {
                all.insert(asset.clone());
            }
        }
        all
    }
}

/// Estimate function size in bytes (ASM code)
/// 
/// Rough estimates:
/// - Statement: ~10 bytes average
/// - Expression: ~5 bytes average
/// - Function overhead: 20 bytes (label + RTS)
fn estimate_function_size(func: &Function) -> usize {
    let stmt_count = count_statements(&func.body);
    // NOTE: M6809 code generation is VERY verbose. Each VPy statement
    // generates 15-30 ASM instructions on average (comparisons, conditionals,
    // function calls, etc.). After measuring real-world code:
    // - 484 VPy lines → 137KB of code (Bank #0 in pang_multi)
    // - That's ~283 bytes per VPy statement including all nested code
    //
    // Using 180 bytes as a conservative-but-realistic estimate.
    // This ensures the bank allocator properly distributes functions.
    let base_size = 100; // Function overhead (prologue, epilogue, locals)
    let stmt_avg = 180; // Average bytes per statement (M6809 is verbose!)
    
    base_size + (stmt_count * stmt_avg)
}

/// Find assets used by a function (DRAW_VECTOR, PLAY_MUSIC, PLAY_SFX, etc.)
fn find_assets_used(body: &[Stmt]) -> HashSet<String> {
    let mut assets = HashSet::new();
    for stmt in body {
        find_assets_in_stmt(stmt, &mut assets);
    }
    assets
}

/// Recursively find asset usages in a statement
fn find_assets_in_stmt(stmt: &Stmt, assets: &mut HashSet<String>) {
    match stmt {
        Stmt::Expr(expr, _) => {
            find_assets_in_expr(expr, assets);
        },
        Stmt::Return(Some(expr), _) => {
            find_assets_in_expr(expr, assets);
        },
        Stmt::Assign { value, .. } => {
            find_assets_in_expr(value, assets);
        },
        Stmt::Let { value, .. } => {
            find_assets_in_expr(value, assets);
        },
        Stmt::If { cond, body, elifs, else_body, .. } => {
            find_assets_in_expr(cond, assets);
            for s in body {
                find_assets_in_stmt(s, assets);
            }
            for (elif_cond, elif_body) in elifs {
                find_assets_in_expr(elif_cond, assets);
                for s in elif_body {
                    find_assets_in_stmt(s, assets);
                }
            }
            if let Some(else_b) = else_body {
                for s in else_b {
                    find_assets_in_stmt(s, assets);
                }
            }
        },
        Stmt::While { cond, body, .. } => {
            find_assets_in_expr(cond, assets);
            for s in body {
                find_assets_in_stmt(s, assets);
            }
        },
        Stmt::For { start, end, step, body, .. } => {
            find_assets_in_expr(start, assets);
            find_assets_in_expr(end, assets);
            if let Some(st) = step {
                find_assets_in_expr(st, assets);
            }
            for s in body {
                find_assets_in_stmt(s, assets);
            }
        },
        _ => {}
    }
}

/// Recursively find asset usages in an expression
fn find_assets_in_expr(expr: &Expr, assets: &mut HashSet<String>) {
    match expr {
        Expr::Call(call_info) => {
            // Check for asset-using builtins
            let name_upper = call_info.name.to_uppercase();
            if matches!(name_upper.as_str(), 
                "DRAW_VECTOR" | "DRAW_VECTOR_EX" | "PLAY_MUSIC" | "PLAY_SFX" | "LOAD_LEVEL"
            ) {
                // First argument is typically the asset name (string literal)
                if let Some(Expr::StringLit(asset_name)) = call_info.args.first() {
                    assets.insert(asset_name.clone());
                }
            }
            // Also recurse into arguments
            for arg in &call_info.args {
                find_assets_in_expr(arg, assets);
            }
        },
        Expr::MethodCall(method_call) => {
            find_assets_in_expr(&method_call.target, assets);
            for arg in &method_call.args {
                find_assets_in_expr(arg, assets);
            }
        },
        Expr::Binary { left, right, .. } => {
            find_assets_in_expr(left, assets);
            find_assets_in_expr(right, assets);
        },
        Expr::Compare { left, right, .. } => {
            find_assets_in_expr(left, assets);
            find_assets_in_expr(right, assets);
        },
        Expr::Logic { left, right, .. } => {
            find_assets_in_expr(left, assets);
            find_assets_in_expr(right, assets);
        },
        Expr::Not(operand) | Expr::BitNot(operand) => {
            find_assets_in_expr(operand, assets);
        },
        Expr::Index { target, index } => {
            find_assets_in_expr(target, assets);
            find_assets_in_expr(index, assets);
        },
        Expr::List(elements) => {
            for elem in elements {
                find_assets_in_expr(elem, assets);
            }
        },
        Expr::FieldAccess { target, .. } => {
            find_assets_in_expr(target, assets);
        },
        _ => {}
    }
}

/// Count total statements recursively
fn count_statements(body: &[Stmt]) -> usize {
    let mut count = 0;
    for stmt in body {
        count += 1; // This statement
        
        // Recurse into nested statements
        match stmt {
            Stmt::If { body, elifs, else_body, .. } => {
                count += count_statements(body);
                for (_, elif_body) in elifs {
                    count += count_statements(elif_body);
                }
                if let Some(else_b) = else_body {
                    count += count_statements(else_b);
                }
            },
            Stmt::While { body, .. } |
            Stmt::For { body, .. } => {
                count += count_statements(body);
            },
            _ => {}
        }
    }
    count
}

/// Find all function calls in a statement block
fn find_function_calls(body: &[Stmt]) -> Vec<String> {
    let mut calls = Vec::new();
    
    for stmt in body {
        find_calls_in_stmt(stmt, &mut calls);
    }
    
    calls
}

/// Recursively find function calls in a statement
fn find_calls_in_stmt(stmt: &Stmt, calls: &mut Vec<String>) {
    match stmt {
        Stmt::Expr(expr, _) => {
            find_calls_in_expr(expr, calls);
        },
        Stmt::Return(Some(expr), _) => {
            find_calls_in_expr(expr, calls);
        },
        Stmt::Assign { value, .. } => {
            find_calls_in_expr(value, calls);
        },
        Stmt::If { cond, body, elifs, else_body, .. } => {
            find_calls_in_expr(cond, calls);
            for s in body {
                find_calls_in_stmt(s, calls);
            }
            for (elif_cond, elif_body) in elifs {
                find_calls_in_expr(elif_cond, calls);
                for s in elif_body {
                    find_calls_in_stmt(s, calls);
                }
            }
            if let Some(else_b) = else_body {
                for s in else_b {
                    find_calls_in_stmt(s, calls);
                }
            }
        },
        Stmt::While { cond, body, .. } => {
            find_calls_in_expr(cond, calls);
            for s in body {
                find_calls_in_stmt(s, calls);
            }
        },
        Stmt::For { start, end, step, body, .. } => {
            find_calls_in_expr(start, calls);
            find_calls_in_expr(end, calls);
            if let Some(st) = step {
                find_calls_in_expr(st, calls);
            }
            for s in body {
                find_calls_in_stmt(s, calls);
            }
        },
        _ => {}
    }
}

/// Recursively find function calls in an expression
fn find_calls_in_expr(expr: &Expr, calls: &mut Vec<String>) {
    match expr {
        Expr::Call(call_info) => {
            calls.push(call_info.name.clone());
            for arg in &call_info.args {
                find_calls_in_expr(arg, calls);
            }
        },
        Expr::MethodCall(method_call) => {
            find_calls_in_expr(&method_call.target, calls);
            for arg in &method_call.args {
                find_calls_in_expr(arg, calls);
            }
        },
        Expr::Binary { left, right, .. } => {
            find_calls_in_expr(left, calls);
            find_calls_in_expr(right, calls);
        },
        Expr::Compare { left, right, .. } => {
            find_calls_in_expr(left, calls);
            find_calls_in_expr(right, calls);
        },
        Expr::Logic { left, right, .. } => {
            find_calls_in_expr(left, calls);
            find_calls_in_expr(right, calls);
        },
        Expr::Not(operand) | Expr::BitNot(operand) => {
            find_calls_in_expr(operand, calls);
        },
        Expr::Index { target, index } => {
            find_calls_in_expr(target, calls);
            find_calls_in_expr(index, calls);
        },
        Expr::List(elements) => {
            for elem in elements {
                find_calls_in_expr(elem, calls);
            }
        },
        Expr::FieldAccess { target, .. } => {
            find_calls_in_expr(target, calls);
        },
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use vpy_parser::{Module, ModuleMeta, Item, Function};

    #[test]
    fn test_call_graph_creation() {
        let graph = CallGraph::new();
        assert!(graph.edges.is_empty());
        assert!(graph.nodes.is_empty());
    }
    
    #[test]
    fn test_add_node() {
        let mut graph = CallGraph::new();
        graph.add_node(FunctionNode {
            name: "test_func".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        assert_eq!(graph.nodes.len(), 1);
        assert!(graph.nodes.contains_key("test_func"));
    }
    
    #[test]
    fn test_add_edge() {
        let mut graph = CallGraph::new();
        graph.add_edge(CallEdge {
            from: "main".to_string(),
            to: "helper".to_string(),
        });
        
        assert_eq!(graph.edges.len(), 1);
        assert_eq!(graph.callees("main"), vec!["helper"]);
    }
    
    #[test]
    fn test_from_module_simple() {
        // Create minimal module with one function
        let module = Module {
            items: vec![
                Item::Function(Function {
                    name: "main".to_string(),
                    line: 0,
                    params: vec![],
                    body: vec![],
                    frame_group: None,
                })
            ],
            meta: ModuleMeta::default(),
            imports: vec![],
        };
        
        let graph = CallGraph::from_module(&module);
        assert_eq!(graph.nodes.len(), 1);
        assert!(graph.nodes.contains_key("main"));
    }
    
    #[test]
    fn test_build_clusters_single_function() {
        let mut graph = CallGraph::new();
        graph.add_node(FunctionNode {
            name: "main".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        let clusters = graph.build_clusters(&HashMap::new());
        
        // Single function = single cluster
        assert_eq!(clusters.len(), 1);
        assert!(clusters[0].functions.contains(&"main".to_string()));
    }
    
    #[test]
    fn test_build_clusters_call_edge() {
        let mut graph = CallGraph::new();
        
        graph.add_node(FunctionNode {
            name: "caller".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        graph.add_node(FunctionNode {
            name: "callee".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        graph.add_edge(CallEdge::new("caller".to_string(), "callee".to_string()));
        
        let clusters = graph.build_clusters(&HashMap::new());
        
        // Two connected functions = one cluster
        assert_eq!(clusters.len(), 1);
        assert_eq!(clusters[0].functions.len(), 2);
    }
    
    #[test]
    fn test_build_clusters_shared_asset() {
        let mut graph = CallGraph::new();
        
        let mut assets = HashSet::new();
        assets.insert("sprite".to_string());
        
        graph.add_node(FunctionNode {
            name: "draw_a".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: assets.clone(),
        });
        
        graph.add_node(FunctionNode {
            name: "draw_b".to_string(),
            size_bytes: 100,
            is_critical: false,
            assets_used: assets.clone(), // Same asset
        });
        
        let mut asset_sizes = HashMap::new();
        asset_sizes.insert("sprite".to_string(), 500);
        
        let clusters = graph.build_clusters(&asset_sizes);
        
        // Two functions with shared asset = one cluster
        assert_eq!(clusters.len(), 1);
        assert_eq!(clusters[0].functions.len(), 2);
        assert!(clusters[0].assets.contains("sprite"));
    }
}