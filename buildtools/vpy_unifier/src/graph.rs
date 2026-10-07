//! Module dependency graph
//!
//! Builds a graph of module dependencies to detect cycles and determine merge order

use crate::error::{UnifierError, UnifierResult};
use std::collections::{HashMap, HashSet, VecDeque};
use vpy_parser::ast::Module;

/// Module dependency graph
#[derive(Debug, Clone)]
pub struct ModuleGraph {
    /// All modules by name
    modules: HashMap<String, Module>,
    /// Dependencies: module -> [imports]
    dependencies: HashMap<String, Vec<String>>,
}

impl ModuleGraph {
    /// Create a new empty graph
    pub fn new() -> Self {
        ModuleGraph {
            modules: HashMap::new(),
            dependencies: HashMap::new(),
        }
    }

    /// Add a module to the graph
    pub fn add_module(&mut self, name: String, module: Module) {
        self.modules.insert(name.clone(), module);
        self.dependencies.entry(name).or_insert_with(Vec::new);
    }

    /// Add a dependency edge (from imports to)
    pub fn add_dependency(&mut self, from: String, to: String) -> UnifierResult<()> {
        if !self.dependencies.contains_key(&from) {
            self.dependencies.insert(from.clone(), Vec::new());
        }
        let deps = self.dependencies.get_mut(&from).unwrap();
        if !deps.contains(&to) {
            deps.push(to);
        }
        Ok(())
    }

    /// Get a module by name
    pub fn get_module(&self, name: &str) -> Option<&Module> {
        self.modules.get(name)
    }

    /// Get all module names
    pub fn modules(&self) -> Vec<String> {
        self.modules.keys().cloned().collect()
    }

    /// Get dependencies of a module
    pub fn get_dependencies(&self, name: &str) -> Vec<String> {
        self.dependencies
            .get(name)
            .map(|deps| deps.clone())
            .unwrap_or_default()
    }

    /// Detect circular dependencies using DFS
    ///
    /// Returns Some(cycle path) if found, None if acyclic
    pub fn detect_cycles(&self) -> Option<Vec<String>> {
        let mut visited = HashSet::new();
        let mut rec_stack = HashSet::new();

        for module_name in self.modules.keys() {
            if !visited.contains(module_name) {
                if let Some(cycle) = self.dfs_visit(
                    module_name.clone(),
                    &mut visited,
                    &mut rec_stack,
                    &mut Vec::new(),
                ) {
                    return Some(cycle);
                }
            }
        }
        None
    }

    /// DFS visit for cycle detection
    fn dfs_visit(
        &self,
        node: String,
        visited: &mut HashSet<String>,
        rec_stack: &mut HashSet<String>,
        path: &mut Vec<String>,
    ) -> Option<Vec<String>> {
        visited.insert(node.clone());
        rec_stack.insert(node.clone());
        path.push(node.clone());

        for neighbor in self.get_dependencies(&node) {
            if !visited.contains(&neighbor) {
                if let Some(cycle) =
                    self.dfs_visit(neighbor, visited, rec_stack, path)
                {
                    return Some(cycle);
                }
            } else if rec_stack.contains(&neighbor) {
                // Found cycle: return path from neighbor to here
                if let Some(start_idx) = path.iter().position(|n| n == &neighbor) {
                    let mut cycle = path[start_idx..].to_vec();
                    cycle.push(neighbor);
                    return Some(cycle);
                }
            }
        }

        path.pop();
        rec_stack.remove(&node);
        None
    }

    /// Topological sort of modules (dependencies first)
    ///
    /// Returns modules in order: dependencies must appear before dependents
    pub fn topological_sort(&self) -> UnifierResult<Vec<String>> {
        // Check for cycles first
        if let Some(cycle) = self.detect_cycles() {
            return Err(UnifierError::CircularDependency(format!(
                "{:?}",
                cycle
            )));
        }

        let mut in_degree: HashMap<String, usize> = HashMap::new();
        let mut adj_list: HashMap<String, Vec<String>> = HashMap::new();

        // Initialize in-degrees (inverted: who depends on me)
        for module in self.modules.keys() {
            in_degree.insert(module.clone(), 0);
            adj_list.insert(module.clone(), Vec::new());
        }

        // Build adjacency list (inverted: who depends on whom)
        for (module, deps) in &self.dependencies {
            for dep in deps {
                in_degree.entry(module.clone())
                    .and_modify(|e| *e += 1);
                adj_list.entry(dep.clone())
                    .or_insert_with(Vec::new)
                    .push(module.clone());
            }
        }

        // Kahn's algorithm: collect nodes with 0 in-degree
        // Sorted so the merge order (and so the generated code) is deterministic.
        let mut roots: Vec<String> = in_degree
            .iter()
            .filter(|(_, degree)| **degree == 0)
            .map(|(module, _)| module.clone())
            .collect();
        roots.sort();
        let mut queue: VecDeque<String> = roots.into();
        for dependents in adj_list.values_mut() {
            dependents.sort();
        }

        let mut result = Vec::new();

        while let Some(node) = queue.pop_front() {
            result.push(node.clone());

            // For each dependent
            for dependent in adj_list.get(&node).unwrap_or(&Vec::new()) {
                in_degree.entry(dependent.clone())
                    .and_modify(|e| *e -= 1);
                if in_degree[dependent] == 0 {
                    queue.push_back(dependent.clone());
                }
            }
        }

        if result.len() != self.modules.len() {
            return Err(UnifierError::CircularDependency(
                "Failed to topologically sort".to_string(),
            ));
        }

        Ok(result)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_graph_new() {
        let graph = ModuleGraph::new();
        assert_eq!(graph.modules(), Vec::<String>::new());
    }

    #[test]
    fn test_add_module() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: Default::default(),
            imports: vec![],
        };
        graph.add_module("test".to_string(), module.clone());
        
        assert_eq!(graph.modules(), vec!["test".to_string()]);
        assert!(graph.get_module("test").is_some());
    }

    #[test]
    fn test_add_dependency() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: Default::default(),
            imports: vec![],
        };
        graph.add_module("main".to_string(), module.clone());
        graph.add_module("util".to_string(), module);
        
        graph.add_dependency("main".to_string(), "util".to_string()).unwrap();
        assert_eq!(graph.get_dependencies("main"), vec!["util".to_string()]);
    }

    #[test]
    fn test_detect_no_cycle() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: Default::default(),
            imports: vec![],
        };
        
        graph.add_module("a".to_string(), module.clone());
        graph.add_module("b".to_string(), module.clone());
        graph.add_module("c".to_string(), module);
        
        graph.add_dependency("b".to_string(), "a".to_string()).unwrap();
        graph.add_dependency("c".to_string(), "b".to_string()).unwrap();
        
        assert!(graph.detect_cycles().is_none());
    }

    #[test]
    fn test_detect_cycle() {
        let mut graph = ModuleGraph::new();
        let module = Module {
            items: vec![],
            meta: Default::default(),
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
            meta: Default::default(),
            imports: vec![],
        };
        
        graph.add_module("util".to_string(), module.clone());
        graph.add_module("input".to_string(), module.clone());
        graph.add_module("main".to_string(), module);
        
        // main imports input, input imports util
        graph.add_dependency("input".to_string(), "util".to_string()).unwrap();
        graph.add_dependency("main".to_string(), "input".to_string()).unwrap();
        
        let order = graph.topological_sort().unwrap();
        
        // util must come before input, input must come before main
        assert_eq!(order.len(), 3);
        let util_idx = order.iter().position(|x| x == "util").unwrap();
        let input_idx = order.iter().position(|x| x == "input").unwrap();
        let main_idx = order.iter().position(|x| x == "main").unwrap();
        
        assert!(util_idx < input_idx);
        assert!(input_idx < main_idx);
    }
}
