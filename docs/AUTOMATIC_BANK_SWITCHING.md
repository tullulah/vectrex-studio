# Automatic Bank Switching Specification

**Version**: 2.0
**Date**: 2026-03-10
**Status**: ✅ Implemented (4-bank, 4×16 KB)

## Overview

VPy implements **automatic bank switching** that is transparent to the developer. The
compiler analyses the code, assigns functions and assets to banks automatically, and
generates all bank-switching wrappers. The developer only adds two `META` directives —
the rest is automatic.

**Current implementation:** 4-bank (4×16 KB = 64 KB total). Banks 0–2 are switchable
at `$0000–$3FFF`; Bank 3 (helpers) is fixed at `$4000–$7FFF`. Bank switching uses
`STA $DF00`.

> **Note on larger configurations:** Configs with `num_banks > 4` compile but
> cross-bank symbol resolution is incomplete. Use 4-bank for production games.

## Goals

✅ **Zero Configuration**: Developer never mentions banks in code
✅ **Transparent**: Same code works on 64KB or 4MB ROM
✅ **Optimal**: Algorithm groups related functions together
✅ **Safe**: No bank switching bugs possible
✅ **Debuggable**: Stack traces show the current bank

## Architecture

### Memory Map

```
ROM Layout:
  0x0000-0x3FFF: Banked ROM window (16KB) ← Changes based on register
  0x4000-0x7FFF: Fixed ROM (16KB)         ← Always last bank (FIXED_BANK)

Hardware Register:
  0x4000: ROM_BANK_REG (write-only)

RAM Variables:
  CURRENT_ROM_BANK: 1 byte (tracks current bank)
```

### Bank Configuration (META Directives)

```python
# 4-bank 64 KB configuration (current recommended):
META ROM_TOTAL_SIZE = 65536    # 64 KB total
META ROM_BANK_SIZE  = 16384    # 16 KB per bank

# Compiler calculates automatically:
# ROM_BANK_COUNT = 65536 / 16384 = 4 banks
# HELPERS_BANK = 3 (last bank, fixed at $4000-$7FFF)
# BANKED_BANKS = 0-2 (switched in at $0000-$3FFF via STA $DF00)
```

> Larger configurations (e.g. 512 KB) are possible in principle but cross-bank
> symbol resolution is not yet complete.

### Fixed Bank Strategy

**Fixed Bank** (last bank, not switchable):
- `main()` function
- Interrupt handlers (BIOS vectors)
- Wrappers for cross-bank calls
- Bank switching runtime (SWITCH_TO_BANK)
- Hot functions (called frequently)

**Swappable Banks** (0 to N-2):
- User functions
- Assets (vectors, music)
- Large const data

## Compilation Pipeline

### Phase 1: Call Graph Analysis

**Input**: VPy program AST
**Output**: Call graph with frequencies

```rust
struct CallGraph {
    nodes: HashMap<String, FunctionNode>,  // name → function info
    edges: Vec<CallEdge>,                   // edge = call
}

struct FunctionNode {
    name: String,
    size_bytes: usize,          // Estimated size in ASM
    is_interrupt: bool,         // Interrupt handler?
    call_frequency: u32,        // How many times it is called
}

struct CallEdge {
    from: String,               // Caller function
    to: String,                 // Callee function
    frequency: u32,             // Runtime call count
}
```

**Algorithm**:
```rust
fn build_call_graph(module: &Module) -> CallGraph {
    let mut graph = CallGraph::new();

    // 1. Create nodes (one entry per function)
    for item in &module.items {
        if let Item::Function(func) = item {
            let node = FunctionNode {
                name: func.name.clone(),
                size_bytes: estimate_function_size(func),
                is_interrupt: is_interrupt_handler(&func.name),
                call_frequency: 0,  // Calculated later
            };
            graph.nodes.insert(func.name.clone(), node);
        }
    }

    // 2. Create edges (calls between functions)
    for item in &module.items {
        if let Item::Function(func) = item {
            for call in find_function_calls(&func.body) {
                graph.add_edge(
                    func.name.clone(),
                    call.target.clone(),
                    estimate_call_frequency(&call)
                );
            }
        }
    }

    // 3. Calculate frequencies (propagation from main)
    graph.calculate_frequencies();

    graph
}
```

**Example Call Graph**:
```
main (size: 100 bytes, freq: 1)
  ├─→ level_1_init (size: 200 bytes, freq: 1)
  │     ├─→ load_sprites (size: 300 bytes, freq: 1)
  │     └─→ init_enemies (size: 150 bytes, freq: 1)
  └─→ game_loop (size: 400 bytes, freq: 10000)
        ├─→ update_player (size: 250 bytes, freq: 10000)
        ├─→ update_enemies (size: 300 bytes, freq: 10000)
        └─→ draw_all (size: 500 bytes, freq: 10000)
              ├─→ draw_player (size: 200 bytes, freq: 10000)
              └─→ draw_enemies (size: 250 bytes, freq: 10000)
```

### Phase 2: Function Clustering

**Goal**: Group functions that call each other frequently (minimise cross-bank calls)

```rust
fn cluster_functions(graph: &CallGraph) -> Vec<Cluster> {
    let mut clusters = Vec::new();

    // 1. Identify "hot paths" (frequent paths)
    let hot_paths = graph.find_hot_paths(threshold: 1000);

    // 2. Create a cluster for each hot path
    for path in hot_paths {
        let cluster = Cluster {
            functions: path.nodes.clone(),
            total_size: path.nodes.iter().map(|n| n.size_bytes).sum(),
            call_frequency: path.total_frequency,
        };
        clusters.push(cluster);
    }

    // 3. Merge small clusters (smaller than half a bank)
    merge_small_clusters(&mut clusters, ROM_BANK_SIZE / 2);

    clusters
}

struct Cluster {
    functions: Vec<String>,
    total_size: usize,
    call_frequency: u32,
}
```

### Phase 3: Bank Assignment (Bin Packing)

**Goal**: Assign clusters to banks, minimising fragmentation

```rust
fn assign_banks(
    clusters: Vec<Cluster>,
    config: &BankConfig
) -> HashMap<String, u8> {
    let mut assignments = HashMap::new();
    let mut banks = vec![Bank::new(); config.rom_bank_count];

    // Fixed bank (last) reserved for hot code
    let fixed_bank_id = config.rom_bank_count - 1;

    // 1. Assign critical functions to the fixed bank
    for func in find_critical_functions(&clusters) {
        assignments.insert(func.clone(), fixed_bank_id);
        banks[fixed_bank_id].add(func);
    }

    // 2. Sort clusters by frequency (most called first)
    let mut sorted_clusters = clusters;
    sorted_clusters.sort_by_key(|c| std::cmp::Reverse(c.call_frequency));

    // 3. First-Fit Decreasing bin packing
    for cluster in sorted_clusters {
        // Find a bank with enough space
        let bank_id = banks.iter_mut()
            .position(|b| b.has_space(cluster.total_size))
            .unwrap_or_else(|| panic!("ROM size too small"));

        // Assign all cluster functions to that bank
        for func in &cluster.functions {
            assignments.insert(func.clone(), bank_id as u8);
            banks[bank_id].add(func.clone());
        }
    }

    assignments  // Map: function → bank
}

struct Bank {
    id: u8,
    functions: Vec<String>,
    used_size: usize,
    max_size: usize,
}

impl Bank {
    fn has_space(&self, size: usize) -> bool {
        self.used_size + size <= self.max_size
    }
}
```

**Critical Functions** (always in the fixed bank):
- `main()`
- Interrupt handlers
- Functions called > 1000 times
- Cross-bank call wrappers (generated later)

### Phase 4: Cross-Bank Call Wrapper Generation

**Goal**: Automatically generate wrappers for calls between banks

```rust
fn generate_wrappers(
    graph: &CallGraph,
    assignments: &HashMap<String, u8>
) -> Vec<String> {
    let mut wrappers = Vec::new();

    for edge in &graph.edges {
        let caller_bank = assignments[&edge.from];
        let callee_bank = assignments[&edge.to];

        // If they are in different banks, generate a wrapper
        if caller_bank != callee_bank {
            let wrapper = format_wrapper(
                &edge.to,
                callee_bank,
                caller_bank
            );
            wrappers.push(wrapper);
        }
    }

    wrappers
}
```

**Wrapper Template** (generated ASM):
```asm
; Wrapper to call a function in another bank
; Example: main (bank 31) calls level_1_init (bank 0)

CALL_BANK0_level_1_init:
    ; 1. Save current bank
    LDA CURRENT_ROM_BANK
    PSHS A

    ; 2. Switch to target bank
    LDA #0                  ; Bank 0
    STA CURRENT_ROM_BANK
    STA $4000               ; Write hardware register

    ; 3. Call real function
    JSR level_1_init

    ; 4. Restore original bank
    PULS A
    STA CURRENT_ROM_BANK
    STA $4000

    RTS

; All wrappers go in FIXED_BANK (bank 31)
; So they are always visible from any bank
```

### Phase 5: ASM Section Generation

**Output**: ASM split into per-bank sections

```asm
; ========================================
; BANK 0 (0x0000-0x3FFF when swapped in)
; ========================================
    ORG $0000
BANK0_START:

level_1_init:
    JSR CALL_BANK0_load_sprites
    JSR CALL_BANK0_init_enemies
    RTS

load_sprites:
    ; ... code ...
    RTS

init_enemies:
    ; ... code ...
    RTS

BANK0_END:
    ; Padding to 16KB
    FILL $FF, $4000 - (* - BANK0_START)

; ========================================
; BANK 1 (0x0000-0x3FFF when swapped in)
; ========================================
    ORG $0000
BANK1_START:

game_loop:
    JSR CALL_BANK1_update_player
    JSR CALL_BANK1_update_enemies
    JSR CALL_BANK1_draw_all
    RTS

; ... more bank 1 functions ...

BANK1_END:
    FILL $FF, $4000 - (* - BANK1_START)

; ========================================
; FIXED BANK (bank 31, always at 0x4000-0x7FFF)
; ========================================
    ORG $4000
FIXED_BANK_START:

main:
    ; Initialise bank
    LDA #31
    STA CURRENT_ROM_BANK
    STA $4000

    ; Call level init (bank 0)
    JSR CALL_BANK0_level_1_init

    ; Main loop (bank 1)
MAINLOOP:
    JSR CALL_BANK1_game_loop
    BRA MAINLOOP

; --- Cross-bank call wrappers ---
CALL_BANK0_level_1_init:
    ; ... wrapper code (see above) ...

CALL_BANK0_load_sprites:
    ; ... wrapper code ...

CALL_BANK1_game_loop:
    ; ... wrapper code ...

; --- RAM variables ---
CURRENT_ROM_BANK: FCB 31  ; Current bank

FIXED_BANK_END:
```

### Phase 6: Multi-Bank Binary Generation

**Output**: .rom file with all banks concatenated

```rust
fn generate_multi_bank_rom(
    banks: Vec<BankData>,
    config: &BankConfig
) -> Vec<u8> {
    let mut rom = Vec::new();

    // Concatenate banks in order (0, 1, 2, ..., N-1)
    for bank in banks {
        let mut bank_data = bank.assemble();

        // Pad to exact bank size
        bank_data.resize(config.rom_bank_size, 0xFF);

        rom.extend_from_slice(&bank_data);
    }

    rom
}
```

**ROM file layout**:
```
Offset        Bank    Description
--------------------------------------
0x00000       0       Bank 0 (16KB)
0x04000       1       Bank 1 (16KB)
0x08000       2       Bank 2 (16KB)
...
0x7C000       31      Fixed bank (last 16KB)
```

## Developer Experience

### VPy Code (No bank mentions)

```python
# examples/bigame/src/main.vpy

META TITLE = "Big Game"
META ROM_TOTAL_SIZE = 524288  # 512KB — just this!

# Developer writes NORMAL code:

def main():
    SET_INTENSITY(127)
    level_1_init()

    while True:
        game_loop()

def level_1_init():
    load_sprites()
    init_enemies()

def load_sprites():
    # Load 50 assets
    for i in range(50):
        LOAD_LEVEL(i)

def game_loop():
    update_player()
    update_enemies()
    draw_all()

def update_player():
    pass

def update_enemies():
    pass

def draw_all():
    draw_player()
    draw_enemies()

# NO @bank, NO LOAD_ROM_BANK!
# Compiler does EVERYTHING automatically:
# - Analyses call graph
# - Groups related functions
# - Assigns to banks
# - Generates wrappers
```

### Compilation Output (Verbose Mode)

```
$ cargo run --bin vectrexc -- build bigame.vpy --verbose

Phase 1: Parse AST... OK
Phase 2: Semantic analysis... OK
Phase 3: Call graph analysis...
  ✓ Found 8 functions
  ✓ Built 12 call edges
  ✓ Calculated frequencies
  ✓ Hot functions: main, game_loop, draw_all

Phase 4: Function clustering...
  ✓ Cluster 0: [main, game_loop, update_player] (1.2KB, 10000 calls/sec)
  ✓ Cluster 1: [level_1_init, load_sprites] (0.5KB, 1 call)
  ✓ Cluster 2: [draw_all, draw_player, draw_enemies] (1.0KB, 10000 calls/sec)

Phase 5: Bank assignment...
  ✓ Bank 0: Cluster 1 (level initialisation)
  ✓ Bank 31 (fixed): Cluster 0, Cluster 2, wrappers
  ✓ Total banks used: 2 / 32
  ✓ Fixed bank size: 2.8KB / 8KB (35% full)
  ✓ Cross-bank calls: 2 (level_1_init, load_sprites)

Phase 6: Wrapper generation...
  ✓ Generated CALL_BANK0_level_1_init
  ✓ Generated CALL_BANK0_load_sprites

Phase 7: Assembly emission...
  ✓ Bank 0: 512 bytes
  ✓ Bank 31 (fixed): 2.8KB
  ✓ Total ROM: 32KB / 512KB (6% used)

Phase 8: Multi-bank ROM generation...
  ✓ Written: build/bigame.rom (512KB)

Compilation successful!
```

### Debug Information

**Stack Trace with Current Bank**:
```
Runtime Error: Division by zero at line 42
Call stack:
  [Bank 31] main() at main.vpy:10
  [Bank 31] game_loop() at main.vpy:15
  [Bank 31] update_player() at main.vpy:30
  [Bank 0]  calculate_velocity() at main.vpy:42  ← Error here

Current bank: 0
ROM map: 2 banks in use (0, 31)
```

## Implementation Details

### Data Structures

```rust
// core/src/codegen.rs
pub struct BankConfig {
    pub rom_bank_size: u32,      // 16384 (16KB)
    pub rom_total_size: u32,     // 524288 (512KB)
    pub rom_bank_count: u8,      // 32
    pub fixed_bank: u8,          // 31 (last)
    pub rom_bank_reg: u16,       // 0x4000
}

pub struct FunctionBankMap {
    pub assignments: HashMap<String, u8>,  // function → bank
    pub wrappers: Vec<WrapperCode>,        // generated wrappers
}

pub struct WrapperCode {
    pub name: String,           // CALL_BANK0_level_1_init
    pub target_func: String,    // level_1_init
    pub target_bank: u8,        // 0
    pub asm_code: String,       // Generated ASM code
}

// core/src/backend/m6809/call_graph.rs (NEW)
pub struct CallGraph {
    pub nodes: HashMap<String, FunctionNode>,
    pub edges: Vec<CallEdge>,
}

pub struct FunctionNode {
    pub name: String,
    pub size_bytes: usize,
    pub is_critical: bool,
    pub call_frequency: u32,
}

pub struct CallEdge {
    pub from: String,
    pub to: String,
    pub frequency: u32,
}

// core/src/backend/m6809/bank_optimizer.rs (NEW)
pub struct BankOptimizer {
    config: BankConfig,
    graph: CallGraph,
}

impl BankOptimizer {
    pub fn assign_banks(&self) -> FunctionBankMap;
    pub fn generate_wrappers(&self, map: &FunctionBankMap) -> Vec<WrapperCode>;
}
```

### Files to Create/Modify

**New Files**:
- `core/src/backend/m6809/call_graph.rs` — Call graph analysis
- `core/src/backend/m6809/bank_optimizer.rs` — Bank assignment algorithm
- `core/src/backend/m6809/multi_bank_linker.rs` — ROM generation

**Modified Files**:
- `core/src/parser.rs` — Parse META ROM_TOTAL_SIZE
- `core/src/codegen.rs` — Add BankConfig to CodegenOptions
- `core/src/backend/m6809/mod.rs` — Integrate bank system
- `core/src/backend/m6809/emission.rs` — Emit per-bank sections
- `ide/frontend/src/components/panels/EmulatorPanel.tsx` — Load multi-bank ROMs

## Hardware Requirements

### Minimum (128KB)

```
Components:
- 1× 27C010 EPROM (128KB) - $5
- 1× 74HC373 Latch - $1
- 1× 74HC00 NAND gates - $1
Total: ~$10

Banks: 8 × 16KB
Fixed bank: Bank 7 (0x4000-0x7FFF)
Swappable banks: 0-6 (0x0000-0x3FFF)
```

### Recommended (512KB)

```
Components:
- 1× 29F040 Flash ROM (512KB) - $8
- 1× 74HC373 Latch - $1
- 1× 74HC139 Decoder - $1
Total: ~$12

Banks: 32 × 16KB
Fixed bank: Bank 31
Swappable banks: 0-30
```

### Maximum (4MB)

```
Components:
- 1× 29F320 Flash ROM (4MB) - $15
- 1× ATF1504 CPLD - $5
Total: ~$20

Banks: 256 × 16KB
Fixed bank: Bank 255
Swappable banks: 0-254
```

## Optimisation Strategies

### Hot Code in Fixed Bank

Functions with `call_frequency > 1000` go to the fixed bank:
- Avoids bank switching overhead
- Better performance

### Function Clustering

Algorithm groups functions that call each other frequently:
- Minimises cross-bank calls
- Better locality (though the 6809 has no cache)

### Wrapper Overhead

If function A calls B 100 times, the wrapper runs 100 times:
- Overhead: ~30 cycles per call
- Total: 3000 cycles
- Alternative: Move B to the same bank (0 overhead)

### Bin Packing Efficiency

First-Fit Decreasing vs Best-Fit:
- FFD: Faster, 80–90% efficiency
- BF: Slower, 90–95% efficiency
- VPy uses FFD (sufficient for games)

## Future Enhancements

### Phase 2 (Optional Features)

- [ ] Manual hints: `@bank(fixed)` decorator
- [ ] Profile-guided optimisation (use runtime data)
- [ ] Compressed banks (decompress on load)
- [ ] Bank preloading hints (predict next bank)

### Phase 3 (Advanced)

- [ ] RAM banking (similar system for cartridge RAM)
- [ ] Overlay system (multiple levels not loaded simultaneously)
- [ ] Hot-reload (change bank without interrupting the game loop)

## References

- Game Boy Bank Switching: https://gbdev.io/pandocs/Bank_Switching.html
- NES Mappers: https://www.nesdev.org/wiki/Mapper
- Vectrex Hardware: https://vectrex.fandom.com/wiki/Vectrex_Technical_Information
- Bin Packing Algorithms: https://en.wikipedia.org/wiki/Bin_packing_problem

---

**Last Updated**: 2026-03-10
**Status**: ✅ Implemented and working (4-bank)
