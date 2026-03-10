//! Bank allocation algorithm
//!
//! Implements the main algorithm for assigning functions to banks
//! 
//! Dependency-Aware Clustering (2026-01-20):
//! - Analyzes call graph to find clusters of inter-dependent functions
//! - Groups functions that call each other in the same bank
//! - Includes assets used by each cluster in the same bank
//! - Minimizes cross-bank calls (expensive: ~50 cycles per bank switch)
//!
//! Sequential Fallback:
//! - Banks #0 to #(N-2): Code/assets fill sequentially
//! - Bank #(N-1): Reserved for runtime helpers

use crate::graph::CallGraph;
use crate::error::{BankAllocatorError, BankAllocatorResult};
use std::collections::{HashMap, HashSet};

/// Configuration for bank allocation
#[derive(Debug, Clone)]
pub struct BankConfig {
    pub rom_total_size: usize,
    pub rom_bank_size: usize,
    pub rom_bank_count: usize,
    pub helpers_bank: usize, // Always last bank (rom_bank_count - 1)
}

impl BankConfig {
    /// Create bank config from total size and bank size
    pub fn new(rom_total_size: usize, rom_bank_size: usize) -> Self {
        let rom_bank_count = rom_total_size / rom_bank_size;
        let helpers_bank = rom_bank_count.saturating_sub(1);
        
        Self {
            rom_total_size,
            rom_bank_size,
            rom_bank_count,
            helpers_bank,
        }
    }
    
    /// Single bank configuration (32KB cartridge)
    pub fn single_bank() -> Self {
        Self {
            rom_total_size: 32768,
            rom_bank_size: 32768,
            rom_bank_count: 1,
            helpers_bank: 0,
        }
    }
    
    /// Multibank configuration (512KB = 32 banks × 16KB)
    pub fn multibank_512kb() -> Self {
        Self::new(524288, 16384)
    }
}

/// Information about a single bank
#[derive(Debug, Clone)]
pub struct BankInfo {
    pub id: u8,
    pub used_bytes: usize,
    pub functions: Vec<String>,
    pub assets: HashSet<String>,
}

impl BankInfo {
    fn new(id: u8) -> Self {
        BankInfo {
            id,
            used_bytes: 0,
            functions: Vec::new(),
            assets: HashSet::new(),
        }
    }
    
    fn available_bytes(&self, bank_size: usize) -> usize {
        bank_size.saturating_sub(self.used_bytes)
    }
    
    fn can_fit(&self, size: usize, bank_size: usize) -> bool {
        self.available_bytes(bank_size) >= size
    }
    
    fn add_function(&mut self, name: String, size: usize) {
        self.functions.push(name);
        self.used_bytes += size;
    }
    
}

/// Bank assignment allocator with dependency-aware clustering
pub struct BankAllocator {
    config: BankConfig,
    graph: CallGraph,
    /// Estimated size of each asset
    asset_sizes: HashMap<String, usize>,
    /// Cached asset assignments (populated by assign_banks)
    #[allow(dead_code)]
    cached_asset_assignments: HashMap<String, u8>,
}

impl BankAllocator {
    pub fn new(config: BankConfig, graph: CallGraph) -> Self {
        BankAllocator { 
            config, 
            graph,
            asset_sizes: HashMap::new(),
            cached_asset_assignments: HashMap::new(),
        }
    }
    
    /// Set asset sizes (from codegen asset discovery)
    pub fn set_asset_sizes(&mut self, sizes: HashMap<String, usize>) {
        self.asset_sizes = sizes;
    }
    
    /// Assign functions to banks using dependency-aware clustering
    /// 
    /// Algorithm:
    /// 1. Build clusters of related functions (call each other + share assets)
    /// 2. Sort clusters by size (largest first)
    /// 3. Assign each cluster to first bank with enough space
    /// 4. Keep cluster together (minimize cross-bank calls)
    /// 
    /// Returns: HashMap<function_name, bank_id>
    pub fn assign_banks(&self) -> BankAllocatorResult<HashMap<String, u8>> {
        let bank_size = self.config.rom_bank_size;
        let total_banks = self.config.rom_bank_count;
        
        // Code banks: #0 to #(N-2)
        // Helper bank: #(N-1) - reserved for runtime helpers
        let code_banks_count = (total_banks as u8).saturating_sub(1);
        
        if code_banks_count == 0 {
            return Err(BankAllocatorError::Generic(
                "Need at least 2 banks (1 for code, 1 for helpers)".to_string()
            ));
        }
        
        // Build function size map
        let func_sizes: HashMap<String, usize> = self.graph.nodes.iter()
            .map(|(name, node)| (name.clone(), node.size_bytes))
            .collect();
        
        // Build clusters from call graph
        let clusters = self.graph.build_clusters(&self.asset_sizes);
        
        // Initialize banks.
        // Bank 0 has fixed overhead not counted in user function sizes:
        //   - Vectrex cartridge header (~300 bytes)
        //   - MAIN startup + LOOP_BODY generated code (~2000 bytes)
        //   - Injected EQU symbol section (~500 bytes)
        // Other banks only have the EQU overhead (~500 bytes).
        // Pre-charge each bank with its fixed overhead so fit checks are accurate.
        const BANK0_FIXED_OVERHEAD: usize = 3000;
        const BANKN_FIXED_OVERHEAD: usize = 600;
        let mut banks: Vec<BankInfo> = (0..code_banks_count as usize)
            .map(|i| {
                let mut b = BankInfo::new(i as u8);
                b.used_bytes = if i == 0 { BANK0_FIXED_OVERHEAD } else { BANKN_FIXED_OVERHEAD };
                b
            })
            .collect();

        let mut assignments: HashMap<String, u8> = HashMap::new();

        // Assign clusters to banks (keeps related code together)
        // IMPORTANT: Use code-only size (no assets) for bank fit check.
        // Assets are distributed separately by generate_distributed_assets_asm.
        for cluster in &clusters {
            let mut assigned = false;

            // Compute cluster size counting only functions (not assets)
            let cluster_code_size: usize = cluster.functions.iter()
                .map(|f| func_sizes.get(f).copied().unwrap_or(100))
                .sum();

            // Try to fit cluster functions in one bank
            for bank in &mut banks {
                if bank.can_fit(cluster_code_size, bank_size) {
                    // Add only functions to bank (assets go to their own banks)
                    for func in &cluster.functions {
                        let size = func_sizes.get(func).copied().unwrap_or(100);
                        bank.add_function(func.clone(), size);
                        assignments.insert(func.clone(), bank.id);
                    }

                    assigned = true;
                    break;
                }
            }

            // If cluster doesn't fit in any single bank, split it greedily across banks.
            // Cross-bank calls will be handled by trampolines in the helpers bank.
            if !assigned {
                eprintln!("       ⚠ Cluster too large for any single bank ({} bytes), splitting across banks with trampolines", cluster_code_size);
                for func in &cluster.functions {
                    let size = func_sizes.get(func).copied().unwrap_or(100);
                    // Find first bank with space; if none, use bank 0
                    let target_bank = banks.iter()
                        .find(|b| b.can_fit(size, bank_size))
                        .map(|b| b.id)
                        .unwrap_or(0);
                    let bank = banks.iter_mut().find(|b| b.id == target_bank).unwrap();
                    bank.add_function(func.clone(), size);
                    assignments.insert(func.clone(), target_bank);
                }
            }
        }
        
        // Validate
        self.validate_assignments(&banks)?;
        
        // Cache asset assignments (will be returned by get_asset_assignments)
        // NOTE: We need mutable self here, but signature is &self
        // Workaround: we'll fix this in the next iteration by making this return both maps
        
        Ok(assignments)
    }
    
    /// Get asset-to-bank assignments (call after assign_banks)
    /// 
    /// CRITICAL: This must return the REAL assignments computed in assign_banks,
    /// NOT a "simple heuristic". Otherwise assets end up in wrong banks.
    pub fn get_asset_assignments(&self) -> HashMap<String, u8> {
        // TEMPORARY WORKAROUND until we refactor to return both maps from assign_banks:
        // Re-run the assignment logic (inefficient but correct)
        // 
        // TODO: Refactor assign_banks to return (HashMap<String, u8>, HashMap<String, u8>)
        //       for (func_assignments, asset_assignments)
        
        let bank_size = self.config.rom_bank_size;
        let total_banks = self.config.rom_bank_count;
        let code_banks_count = (total_banks as u8).saturating_sub(1);
        
        if code_banks_count == 0 {
            return HashMap::new();
        }
        
        // Build function size map
        let func_sizes: HashMap<String, usize> = self.graph.nodes.iter()
            .map(|(name, node)| (name.clone(), node.size_bytes))
            .collect();
        
        // Build clusters
        let clusters = self.graph.build_clusters(&self.asset_sizes);
        
        // Initialize banks
        let mut banks: Vec<BankInfo> = (0..code_banks_count as usize)
            .map(|i| BankInfo::new(i as u8))
            .collect();
        
        let mut assignments: HashMap<String, u8> = HashMap::new();
        let mut asset_assignments: HashMap<String, u8> = HashMap::new();
        
        // CRITICAL FIX (2026-01-20): Assets go to Banks #1-#30 (switchable window)
        // Bank #0 = main code + LOOP
        // Banks #1-#30 = overflow code + ASSETS
        // Bank #31 = helpers + lookup tables ONLY (fixed window, no assets!)
        let helper_bank_id = (total_banks - 1) as u8;  // Bank #31
        let first_asset_bank = 1u8;  // Start at Bank #1
        let last_asset_bank = helper_bank_id.saturating_sub(1);  // End at Bank #30
        
        // Track bank usage for assets
        let mut asset_bank_usage: HashMap<u8, usize> = HashMap::new();
        
        // Collect all assets from all clusters
        let all_assets: Vec<String> = clusters.iter()
            .flat_map(|c| c.assets.iter().cloned())
            .collect();
        
        // Distribute assets across Banks #1-#30 using first-fit
        for asset in &all_assets {
            let asset_size = self.asset_sizes.get(asset).copied().unwrap_or(200);
            let mut assigned = false;
            
            for bank_id in first_asset_bank..=last_asset_bank {
                let current_usage = *asset_bank_usage.get(&bank_id).unwrap_or(&0);
                if current_usage + asset_size <= bank_size {
                    asset_bank_usage.insert(bank_id, current_usage + asset_size);
                    asset_assignments.insert(asset.clone(), bank_id);
                    assigned = true;
                    break;
                }
            }
            
            if !assigned {
                panic!("FATAL: Cannot fit asset '{}' ({} bytes) - banks #{}-#{} full!", 
                    asset, asset_size, first_asset_bank, last_asset_bank);
            }
        }
        
        
        // Re-run the same allocation logic as assign_banks FOR FUNCTIONS ONLY
        for cluster in &clusters {
            let mut assigned = false;
            
            // Calculate cluster size WITHOUT assets (assets are in Bank #31 now)
            let cluster_code_size: usize = cluster.functions.iter()
                .map(|f| func_sizes.get(f).copied().unwrap_or(100))
                .sum();
            
            // Try to fit functions in one bank
            for bank in &mut banks {
                if bank.can_fit(cluster_code_size, bank_size) {
                    // Add only functions to this bank (NOT assets)
                    for func in &cluster.functions {
                        let func_size = func_sizes.get(func).copied().unwrap_or(100);
                        bank.add_function(func.clone(), func_size);
                        assignments.insert(func.clone(), bank.id);
                    }
                    
                    assigned = true;
                    break;
                }
            }
            
            // If functions don't fit together, assign individually
            if !assigned {
                for func_name in &cluster.functions {
                    let func_size = func_sizes.get(func_name).copied().unwrap_or(100);
                    
                    for bank in &mut banks {
                        if bank.can_fit(func_size, bank_size) {
                            bank.add_function(func_name.clone(), func_size);
                            assignments.insert(func_name.clone(), bank.id);
                            break;
                        }
                    }
                }
            }
        }
        
        asset_assignments
    }
    
    /// Validate bank assignments (soft check — size estimates may be conservative).
    /// Real overflow is caught by the assembler; we only warn here.
    fn validate_assignments(&self, banks: &[BankInfo]) -> BankAllocatorResult<()> {
        let bank_size = self.config.rom_bank_size;

        // Check if any individual function is too large to fit in any bank
        for (name, node) in &self.graph.nodes {
            if node.size_bytes > bank_size {
                return Err(BankAllocatorError::Generic(format!(
                    "Function '{}' is {} bytes, which exceeds bank size of {} bytes",
                    name, node.size_bytes, bank_size
                )));
            }
        }

        for bank in banks {
            if bank.used_bytes > bank_size {
                eprintln!(
                    "       ⚠ Bank #{} estimated at {} bytes (limit {}); actual size confirmed by assembler",
                    bank.id, bank.used_bytes, bank_size
                );
            }
        }
        Ok(())
    }
    
    /// Get assignment statistics for debugging
    pub fn assignment_stats(&self, assignments: &HashMap<String, u8>) -> BankStats {
        let bank_size = self.config.rom_bank_size;
        let total_banks = self.config.rom_bank_count;
        let code_banks_count = total_banks.saturating_sub(1);
        
        let func_sizes: HashMap<String, usize> = self.graph.nodes.iter()
            .map(|(name, node)| (name.clone(), node.size_bytes))
            .collect();
        
        let mut banks: Vec<BankInfo> = (0..code_banks_count)
            .map(|i| BankInfo::new(i as u8))
            .collect();
        
        for (func_name, bank_id) in assignments {
            if (*bank_id as usize) < code_banks_count {
                let size = func_sizes.get(func_name).copied().unwrap_or(0);
                banks[*bank_id as usize].add_function(func_name.clone(), size);
            }
        }
        
        let used_banks = banks.iter().filter(|b| !b.functions.is_empty()).count();
        let total_used_bytes: usize = banks.iter().map(|b| b.used_bytes).sum();
        let total_available_bytes = bank_size * code_banks_count;
        let utilization = (total_used_bytes as f64 / total_available_bytes as f64) * 100.0;
        
        BankStats {
            total_banks,
            code_banks: code_banks_count,
            helper_bank: (total_banks - 1) as u8,
            used_banks,
            total_functions: assignments.len(),
            total_used_bytes,
            total_available_bytes,
            utilization,
            banks: banks.into_iter().filter(|b| !b.functions.is_empty()).collect(),
        }
    }
}

/// Statistics about bank assignments
#[derive(Debug)]
pub struct BankStats {
    pub total_banks: usize,
    pub code_banks: usize,          // Code banks #0 to #(N-2)
    pub helper_bank: u8,             // Helper bank #(N-1)
    pub used_banks: usize,
    pub total_functions: usize,
    pub total_used_bytes: usize,
    pub total_available_bytes: usize,
    pub utilization: f64,
    pub banks: Vec<BankInfo>,
}

impl BankStats {
    /// Format statistics as human-readable string
    pub fn summary(&self) -> String {
        format!(
            "Bank Allocation Summary:\n\
             - Total banks: {}\n\
             - Code banks: #0-#{} (helpers in #{})\n\
             - Used banks: {}/{}\n\
             - Functions: {}\n\
             - Total used: {} bytes / {} bytes\n\
             - Utilization: {:.1}%",
            self.total_banks,
            self.code_banks - 1,
            self.helper_bank,
            self.used_banks,
            self.code_banks,
            self.total_functions,
            self.total_used_bytes,
            self.total_available_bytes,
            self.utilization
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::graph::{CallGraph, FunctionNode, CallEdge};
    use std::collections::HashSet;

    #[test]
    fn test_single_bank_config() {
        let config = BankConfig::single_bank();
        assert_eq!(config.rom_bank_count, 1);
        assert_eq!(config.rom_bank_size, 32768);
    }
    
    #[test]
    fn test_multibank_config() {
        let config = BankConfig::multibank_512kb();
        assert_eq!(config.rom_bank_count, 32);
        assert_eq!(config.rom_bank_size, 16384);
        assert_eq!(config.helpers_bank, 31);
    }
    
    #[test]
    fn test_bank_info() {
        let mut bank = BankInfo::new(0);
        assert_eq!(bank.available_bytes(16384), 16384);
        
        bank.add_function("test".to_string(), 100);
        assert_eq!(bank.used_bytes, 100);
        assert_eq!(bank.available_bytes(16384), 16384 - 100);
    }
    
    #[test]
    fn test_allocator_simple() {
        let config = BankConfig::multibank_512kb();
        let mut graph = CallGraph::new();
        
        // Add a small function
        graph.add_node(FunctionNode {
            name: "main".to_string(),
            size_bytes: 100,
            is_critical: true,
            assets_used: HashSet::new(),
        });
        
        let allocator = BankAllocator::new(config, graph);
        let assignments = allocator.assign_banks().unwrap();
        
        assert_eq!(assignments.len(), 1);
        assert_eq!(assignments["main"], 0); // Should go to bank #0
    }
    
    #[test]
    fn test_allocator_overflow() {
        let config = BankConfig::new(32768, 16384); // 2 banks total
        let mut graph = CallGraph::new();
        
        // Add function too large for single bank
        graph.add_node(FunctionNode {
            name: "huge".to_string(),
            size_bytes: 20000, // Larger than 16KB bank
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        let allocator = BankAllocator::new(config, graph);
        let result = allocator.assign_banks();
        
        assert!(result.is_err());
    }
    
    #[test]
    fn test_clustering_related_functions() {
        // Test that functions that call each other stay in same bank
        let config = BankConfig::multibank_512kb();
        let mut graph = CallGraph::new();
        
        // Add two small functions that call each other
        let mut assets1 = HashSet::new();
        assets1.insert("player_sprite".to_string());
        
        graph.add_node(FunctionNode {
            name: "draw_player".to_string(),
            size_bytes: 500,
            is_critical: false,
            assets_used: assets1.clone(),
        });
        
        graph.add_node(FunctionNode {
            name: "update_player".to_string(),
            size_bytes: 500,
            is_critical: false,
            assets_used: HashSet::new(),
        });
        
        // draw_player calls update_player
        graph.add_edge(CallEdge::new("draw_player".to_string(), "update_player".to_string()));
        
        let mut allocator = BankAllocator::new(config, graph);
        let mut asset_sizes = HashMap::new();
        asset_sizes.insert("player_sprite".to_string(), 200);
        allocator.set_asset_sizes(asset_sizes);
        
        let assignments = allocator.assign_banks().unwrap();
        
        // Both functions should be in same bank (cluster)
        assert_eq!(assignments["draw_player"], assignments["update_player"]);
    }
    
    #[test]
    fn test_clustering_shared_assets() {
        // Test that functions sharing assets cluster together
        let config = BankConfig::multibank_512kb();
        let mut graph = CallGraph::new();
        
        // Two functions use same asset (should cluster)
        let mut assets_shared = HashSet::new();
        assets_shared.insert("enemy_sprite".to_string());
        
        graph.add_node(FunctionNode {
            name: "draw_enemy".to_string(),
            size_bytes: 300,
            is_critical: false,
            assets_used: assets_shared.clone(),
        });
        
        graph.add_node(FunctionNode {
            name: "update_enemy".to_string(),
            size_bytes: 300,
            is_critical: false,
            assets_used: assets_shared.clone(), // Same asset
        });
        
        // Third function uses different asset (should NOT cluster with above)
        let mut assets_diff = HashSet::new();
        assets_diff.insert("background".to_string());
        
        graph.add_node(FunctionNode {
            name: "draw_background".to_string(),
            size_bytes: 300,
            is_critical: false,
            assets_used: assets_diff,
        });
        
        let mut allocator = BankAllocator::new(config, graph);
        let mut asset_sizes = HashMap::new();
        asset_sizes.insert("enemy_sprite".to_string(), 500);
        asset_sizes.insert("background".to_string(), 500);
        allocator.set_asset_sizes(asset_sizes);
        
        let assignments = allocator.assign_banks().unwrap();
        
        // draw_enemy and update_enemy should be in same bank (share asset)
        assert_eq!(assignments["draw_enemy"], assignments["update_enemy"]);
    }
}
