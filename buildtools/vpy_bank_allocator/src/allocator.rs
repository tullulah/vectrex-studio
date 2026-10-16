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

/// Fixed bytes charged to bank #0 when function sizes are AST estimates: cartridge
/// header, START, MAIN's init code (measured: 60-200 bytes in `examples/`, plus margin).
/// MAIN/LOOP_BODY themselves are charged on top (they always live in bank #0).
pub const ESTIMATED_BANK0_OVERHEAD: usize = 1024;
/// Fixed bytes charged to every other code bank when sizes are AST estimates (measured:
/// 0 — RAM EQUs take no ROM; this is margin for the estimates).
pub const ESTIMATED_BANKN_OVERHEAD: usize = 512;
/// Bytes kept free in every code bank when sizes are measured from assembled code. The
/// measurement and the final link assemble the same text; the margin only covers the
/// few operands whose addressing mode (direct vs extended) can change once cross-bank
/// symbols get their final values.
pub const MEASURED_BANK_MARGIN: usize = 128;

/// MAIN and LOOP_BODY are always emitted into bank #0, whatever the allocator says.
pub fn is_pinned_to_bank0(name: &str) -> bool {
    name.eq_ignore_ascii_case("main") || name.eq_ignore_ascii_case("loop")
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
    /// Fixed bytes per code bank (index = bank id; banks past the end use the last value).
    bank_fixed_bytes: Vec<usize>,
    /// Sizes come from assembled code: pinned functions are already inside
    /// `bank_fixed_bytes[0]`, and code that does not fit is an error, not a warning.
    measured: bool,
}

/// Outcome of packing the clusters into `code_banks` banks.
struct Packing {
    assignments: HashMap<String, u8>,
    banks: Vec<BankInfo>,
    /// Functions that fit no bank: (name, size).
    unplaced: Vec<(String, usize)>,
}

impl BankAllocator {
    pub fn new(config: BankConfig, graph: CallGraph) -> Self {
        BankAllocator {
            config,
            graph,
            asset_sizes: HashMap::new(),
            cached_asset_assignments: HashMap::new(),
            bank_fixed_bytes: vec![ESTIMATED_BANK0_OVERHEAD, ESTIMATED_BANKN_OVERHEAD],
            measured: false,
        }
    }

    /// Set asset sizes (from codegen asset discovery)
    pub fn set_asset_sizes(&mut self, sizes: HashMap<String, usize>) {
        self.asset_sizes = sizes;
    }

    /// Replace the AST estimates with sizes measured from assembled code.
    ///
    /// * `function_sizes` - bytes per function, keyed by function name or by its
    ///   upper-case assembly label (both are looked up).
    /// * `bank_fixed_bytes` - bytes of each code bank that are not movable functions
    ///   (bank #0: header, START, MAIN and LOOP_BODY). Index = bank id; banks past the
    ///   end use the last value.
    ///
    /// After this call, code that does not fit the ROM makes `assign_banks` fail with
    /// [`BankAllocatorError::DoesNotFit`].
    pub fn set_measured_sizes(&mut self, function_sizes: &HashMap<String, usize>, bank_fixed_bytes: &[usize]) {
        for (name, node) in self.graph.nodes.iter_mut() {
            if let Some(&size) = function_sizes.get(name)
                .or_else(|| function_sizes.get(&name.to_uppercase()))
            {
                node.size_bytes = size;
            }
        }
        self.bank_fixed_bytes = bank_fixed_bytes.iter().map(|b| b + MEASURED_BANK_MARGIN).collect();
        if self.bank_fixed_bytes.is_empty() {
            self.bank_fixed_bytes.push(MEASURED_BANK_MARGIN);
        }
        self.measured = true;
    }

    /// Return the code size (bytes) of each function — measured if
    /// `set_measured_sizes` was called, estimated otherwise.
    pub fn get_function_sizes(&self) -> HashMap<String, usize> {
        self.graph.nodes.iter()
            .map(|(name, node)| (name.clone(), node.size_bytes))
            .collect()
    }

    /// Fixed bytes charged to `bank_id` before any movable function is placed.
    pub fn bank_fixed_bytes(&self, bank_id: usize) -> usize {
        let fixed = self.bank_fixed_bytes.get(bank_id)
            .or_else(|| self.bank_fixed_bytes.last())
            .copied()
            .unwrap_or(0);
        if bank_id == 0 && !self.measured {
            // Estimates: MAIN and LOOP_BODY come on top of the fixed bank-0 code.
            fixed + self.pinned_functions().iter().map(|(_, s)| *s).sum::<usize>()
        } else {
            fixed
        }
    }

    fn pinned_functions(&self) -> Vec<(String, usize)> {
        let mut pinned: Vec<(String, usize)> = self.graph.nodes.iter()
            .filter(|(name, _)| is_pinned_to_bank0(name))
            .map(|(name, node)| (name.clone(), node.size_bytes))
            .collect();
        pinned.sort();
        pinned
    }

    /// Pack every movable function into `code_banks` banks (first fit, cluster by cluster).
    fn pack(&self, code_banks: usize) -> Packing {
        let bank_size = self.config.rom_bank_size;

        // MAIN/LOOP are not movable: drop them from the graph so they neither take a slot
        // nor glue every function they call into one giant cluster.
        let mut movable = self.graph.clone();
        movable.nodes.retain(|name, _| !is_pinned_to_bank0(name));
        let clusters = movable.build_clusters(&self.asset_sizes);
        let size_of = |f: &String| movable.nodes.get(f).map(|n| n.size_bytes).unwrap_or(100);

        let mut banks: Vec<BankInfo> = (0..code_banks)
            .map(|i| {
                let mut b = BankInfo::new(i as u8);
                b.used_bytes = self.bank_fixed_bytes(i);
                b
            })
            .collect();
        let mut assignments: HashMap<String, u8> = HashMap::new();
        for (name, _) in self.pinned_functions() {
            assignments.insert(name, 0);
        }
        let mut unplaced = Vec::new();

        // IMPORTANT: Use code-only size (no assets) for bank fit check.
        // Assets are distributed separately by generate_distributed_assets_asm.
        for cluster in &clusters {
            // Sorted: HashSet iteration order is random, and the order decides the split.
            let mut funcs_sorted: Vec<&String> = cluster.functions.iter().collect();
            funcs_sorted.sort();
            let cluster_code_size: usize = funcs_sorted.iter().map(|f| size_of(f)).sum();

            // Keep the cluster in one bank when it fits (no cross-bank calls inside it).
            if let Some(bank) = banks.iter_mut().find(|b| b.can_fit(cluster_code_size, bank_size)) {
                for func in funcs_sorted {
                    bank.add_function(func.clone(), size_of(func));
                    assignments.insert(func.clone(), bank.id);
                }
                continue;
            }

            // Split the cluster greedily; cross-bank calls go through trampolines in the
            // helpers bank.
            for func in funcs_sorted {
                let size = size_of(func);
                match banks.iter_mut().find(|b| b.can_fit(size, bank_size)) {
                    Some(bank) => {
                        bank.add_function(func.clone(), size);
                        assignments.insert(func.clone(), bank.id);
                    }
                    None => unplaced.push((func.clone(), size)),
                }
            }
        }

        Packing { assignments, banks, unplaced }
    }

    /// Assign functions to banks using dependency-aware clustering
    ///
    /// Algorithm:
    /// 1. MAIN and LOOP go to bank #0 (the code generator always emits them there)
    /// 2. Build clusters of the other functions (call each other + share assets)
    /// 3. Sort clusters by size (largest first)
    /// 4. Assign each cluster to the first bank with enough space, splitting it across
    ///    banks (trampolines) when no bank holds it whole
    ///
    /// Returns: HashMap<function_name, bank_id>
    pub fn assign_banks(&self) -> BankAllocatorResult<HashMap<String, u8>> {
        let bank_size = self.config.rom_bank_size;
        let total_banks = self.config.rom_bank_count;

        // Code banks: #0 to #(N-2)
        // Helper bank: #(N-1) - reserved for runtime helpers
        let code_banks_count = total_banks.saturating_sub(1);

        if code_banks_count == 0 {
            return Err(BankAllocatorError::Generic(
                "Need at least 2 banks (1 for code, 1 for helpers)".to_string()
            ));
        }

        self.validate_function_sizes()?;
        if self.measured && self.bank_fixed_bytes(0) > bank_size {
            let fixed = self.bank_fixed_bytes(0) - MEASURED_BANK_MARGIN;
            return Err(BankAllocatorError::DoesNotFit(format!(
                "Bank #0 overflow: its fixed code (cartridge header, START, main() and loop()) is \
                 {} bytes; with the {}-byte safety margin that is {} bytes over the {}-byte bank. \
                 main() and loop() always live in bank #0: move code out of them into functions \
                 so the allocator can place it in other banks.",
                fixed, MEASURED_BANK_MARGIN, self.bank_fixed_bytes(0) - bank_size, bank_size
            )));
        }

        let packing = self.pack(code_banks_count);

        if !packing.unplaced.is_empty() {
            if self.measured {
                return Err(BankAllocatorError::DoesNotFit(self.does_not_fit_message(&packing)));
            }
            // Estimated sizes are only a guess: keep the old behaviour (bank #0 takes the
            // rest) and let the assembled code decide.
            let mut assignments = packing.assignments;
            for (func, size) in &packing.unplaced {
                eprintln!(
                    "       ⚠ Function '{}' (~{} bytes, estimated) fits no bank; placing it in bank #0",
                    func, size
                );
                assignments.insert(func.clone(), 0);
            }
            return Ok(assignments);
        }

        self.validate_assignments(&packing.banks)?;
        Ok(packing.assignments)
    }

    /// The precise "does not fit" report: how many bytes are over, and the ROM size that
    /// would hold the code.
    fn does_not_fit_message(&self, failed: &Packing) -> String {
        let bank_size = self.config.rom_bank_size;
        let code_banks = self.config.rom_bank_count.saturating_sub(1);
        let unplaced_bytes: usize = failed.unplaced.iter().map(|(_, s)| s).sum();
        let free_bytes: usize = failed.banks.iter()
            .map(|b| b.available_bytes(bank_size))
            .sum();

        // Smallest number of code banks that holds everything (bank ids are u8).
        let needed_code_banks = (code_banks + 1..255)
            .find(|&n| self.pack(n).unplaced.is_empty());

        let mut largest: Vec<&(String, usize)> = failed.unplaced.iter().collect();
        largest.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
        let list: Vec<String> = largest.iter().take(5)
            .map(|(n, s)| format!("{} ({} bytes)", n, s))
            .collect();

        let mut msg = format!(
            "Program code does not fit the ROM: {} bytes of functions found no room in code banks \
             #0-#{} ({} banks x {} bytes, {} bytes still free but in pieces too small). \
             Short by at least {} bytes. Unplaced: {}{}.",
            unplaced_bytes,
            code_banks.saturating_sub(1),
            code_banks,
            bank_size,
            free_bytes,
            unplaced_bytes.saturating_sub(free_bytes).max(1),
            list.join(", "),
            if failed.unplaced.len() > 5 { format!(" and {} more", failed.unplaced.len() - 5) } else { String::new() },
        );
        match needed_code_banks {
            Some(n) => {
                let rom = ((n + 1) * bank_size).next_power_of_two();
                msg.push_str(&format!(
                    " The code needs {} code banks + 1 helpers bank: set META ROM_TOTAL_SIZE = {} \
                     (with META ROM_BANK_SIZE = {}), or make the code smaller.",
                    n, rom, bank_size
                ));
            }
            None => msg.push_str(" Make the code smaller."),
        }
        msg
    }

    /// A function bigger than a whole bank can never be placed.
    fn validate_function_sizes(&self) -> BankAllocatorResult<()> {
        let bank_size = self.config.rom_bank_size;
        let mut names: Vec<&String> = self.graph.nodes.keys().collect();
        names.sort();
        for name in names {
            let node = &self.graph.nodes[name];
            if is_pinned_to_bank0(name) && self.measured {
                continue; // already inside bank #0's fixed bytes
            }
            let room = bank_size.saturating_sub(self.bank_fixed_bytes(1));
            if node.size_bytes > room {
                let msg = format!(
                    "Function '{}' is {} bytes, more than one {}-byte bank can hold for code \
                     ({} bytes after the bank's fixed code). A function cannot span banks: \
                     split it into smaller functions.",
                    name, node.size_bytes, bank_size, room
                );
                return Err(if self.measured {
                    BankAllocatorError::DoesNotFit(msg)
                } else {
                    BankAllocatorError::Generic(msg)
                });
            }
        }
        Ok(())
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
        
        // Track bank usage for assets — pre-seeded with function code sizes below.
        let mut asset_bank_usage: HashMap<u8, usize> = HashMap::new();
        
        // Collect all assets from all clusters
        // Sorted: cluster.assets is a HashSet, so the first-fit order (and the bank each
        // asset lands in) would otherwise change from run to run.
        let mut all_assets: Vec<String> = clusters.iter()
            .flat_map(|c| c.assets.iter().cloned())
            .collect();
        all_assets.sort();
        all_assets.dedup();
        
        // ── PASS 1: assign function code to banks ─────────────────────────────────
        // Must run BEFORE asset assignment so asset first-fit sees how much space
        // each bank already has. (Bug: original code ran asset assignment first,
        // then function assignment — causing both to claim bank_1 independently.)
        for cluster in &clusters {
            let mut assigned = false;
            
            // Calculate cluster code size (assets tracked separately)
            let cluster_code_size: usize = cluster.functions.iter()
                .map(|f| func_sizes.get(f).copied().unwrap_or(100))
                .sum();
            
            // Try to fit functions in one bank
            for bank in &mut banks {
                if bank.can_fit(cluster_code_size, bank_size) {
                    let mut funcs_sorted: Vec<&String> = cluster.functions.iter().collect();
                    funcs_sorted.sort();
                    for func in funcs_sorted {
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
                let mut funcs_sorted: Vec<&String> = cluster.functions.iter().collect();
                funcs_sorted.sort();
                for func_name in funcs_sorted {
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
        
        // Seed asset_bank_usage with function code already assigned to each bank.
        // This ensures asset first-fit only uses space that functions haven't claimed.
        for bank in &banks {
            if bank.used_bytes > 0 {
                asset_bank_usage.insert(bank.id, bank.used_bytes);
            }
        }
        
        // ── PASS 2: distribute assets across Banks #1-#N using first-fit ─────────
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
        
        asset_assignments
    }
    
    /// Validate bank assignments (soft check — only estimates can overflow here, and the
    /// assembled code is the judge).
    fn validate_assignments(&self, banks: &[BankInfo]) -> BankAllocatorResult<()> {
        let bank_size = self.config.rom_bank_size;
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

    fn node(name: &str, size: usize) -> FunctionNode {
        FunctionNode {
            name: name.to_string(),
            size_bytes: size,
            is_critical: name == "main" || name == "loop",
            assets_used: HashSet::new(),
        }
    }

    /// loop() calls everything, as in a real game.
    fn game_graph(funcs: &[(&str, usize)]) -> CallGraph {
        let mut graph = CallGraph::new();
        graph.add_node(node("main", 50));
        graph.add_node(node("loop", 300));
        for (name, size) in funcs {
            graph.add_node(node(name, *size));
            graph.add_edge(CallEdge::new("loop".to_string(), name.to_string()));
        }
        graph
    }

    #[test]
    fn test_main_and_loop_pinned_to_bank0() {
        // Estimated sizes: main/loop are charged to bank #0 and are not glued to the
        // functions they call, so the rest spreads over the banks by size.
        let funcs: Vec<(String, usize)> = (0..6).map(|i| (format!("f{i}"), 6000)).collect();
        let refs: Vec<(&str, usize)> = funcs.iter().map(|(n, s)| (n.as_str(), *s)).collect();
        let allocator = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs));
        let a = allocator.assign_banks().unwrap();
        assert_eq!(a["main"], 0);
        assert_eq!(a["loop"], 0);
        let mut per_bank = [0usize; 3];
        for (f, s) in &refs {
            per_bank[a[*f] as usize] += s;
        }
        // 16384 - 1024 fixed - 350 (main+loop) leaves room for 2 x 6000 in bank #0.
        assert_eq!(per_bank, [12000, 12000, 12000]);
    }

    #[test]
    fn test_measured_sizes_replace_estimates() {
        // Estimates say everything fits bank #0; the measured sizes say it does not.
        let refs = [("a", 100), ("b", 100), ("c", 100)];
        let mut allocator = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs));
        assert!(allocator.assign_banks().unwrap().values().all(|&b| b == 0));

        let mut measured = HashMap::new();
        measured.insert("A".to_string(), 9000); // keyed by assembly label
        measured.insert("B".to_string(), 9000);
        measured.insert("C".to_string(), 9000);
        allocator.set_measured_sizes(&measured, &[2000, 0, 0]);
        assert_eq!(allocator.get_function_sizes()["a"], 9000);
        let a = allocator.assign_banks().unwrap();
        // 2000 fixed + 128 margin + 9000 = 11128; a second function would make 20128.
        let mut banks: Vec<u8> = ["a", "b", "c"].iter().map(|f| a[*f]).collect();
        banks.sort();
        assert_eq!(banks, vec![0, 1, 2]);
    }

    #[test]
    fn test_measured_overflow_is_precise_error() {
        let refs = [("a", 9000), ("b", 9000), ("c", 9000), ("d", 9000)];
        let mut allocator = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs));
        let measured: HashMap<String, usize> = refs.iter().map(|(n, s)| (n.to_string(), *s)).collect();
        allocator.set_measured_sizes(&measured, &[500, 0, 0]);
        let err = allocator.assign_banks().unwrap_err();
        assert!(matches!(err, BankAllocatorError::DoesNotFit(_)), "{err}");
        let msg = err.to_string();
        assert!(msg.contains("9000 bytes of functions found no room"), "{msg}");
        // 4 code banks + helpers = 5 banks -> 128 KB.
        assert!(msg.contains("META ROM_TOTAL_SIZE = 131072"), "{msg}");
        assert!(msg.contains("ROM_BANK_SIZE = 16384"), "{msg}");
    }

    #[test]
    fn test_measured_function_larger_than_bank() {
        let refs = [("huge", 16300)];
        let mut allocator = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs));
        let measured: HashMap<String, usize> = refs.iter().map(|(n, s)| (n.to_string(), *s)).collect();
        allocator.set_measured_sizes(&measured, &[500, 0, 0]);
        let msg = allocator.assign_banks().unwrap_err().to_string();
        assert!(msg.contains("Function 'huge' is 16300 bytes"), "{msg}");
        assert!(msg.contains("split it"), "{msg}");
    }

    #[test]
    fn test_measured_bank0_fixed_overflow() {
        let refs = [("a", 100)];
        let mut allocator = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs));
        let measured: HashMap<String, usize> = refs.iter().map(|(n, s)| (n.to_string(), *s)).collect();
        allocator.set_measured_sizes(&measured, &[17000, 0, 0]);
        let msg = allocator.assign_banks().unwrap_err().to_string();
        assert!(msg.contains("Bank #0 overflow"), "{msg}");
        assert!(msg.contains("744 bytes over"), "{msg}");
    }

    #[test]
    fn test_assignment_is_deterministic() {
        let funcs: Vec<(String, usize)> = (0..20).map(|i| (format!("fn_{i}"), 1500 + (i % 3) * 700)).collect();
        let refs: Vec<(&str, usize)> = funcs.iter().map(|(n, s)| (n.as_str(), *s)).collect();
        let first = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs)).assign_banks().unwrap();
        for _ in 0..8 {
            let again = BankAllocator::new(BankConfig::new(65536, 16384), game_graph(&refs)).assign_banks().unwrap();
            assert_eq!(first, again);
        }
    }
}
