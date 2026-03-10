/// Comprehensive test suite for Phase 3: Unifier
/// Tests basic compilation with Module structures
///
/// NOTE: Tree shaking is implemented in the unifier phase, which runs BEFORE
/// codegen. These tests verify that emit_asm() works correctly with Module
/// structures, but do NOT test tree shaking (which requires unifier integration).
///
/// For tree shaking verification, see:
/// - examples/test_tree_shaking/ (real-world verification)
/// - PHASE3_COMPLETION_STATUS.md (implementation details)

use vectrex_lang::codegen::{CodegenOptions, emit_asm};
use vectrex_lang::ast::{Module, Item, Function, Stmt, Expr, IdentInfo, CallInfo, ModuleMeta};
use vectrex_lang::target::Target;
use std::collections::{BTreeMap, HashMap, BTreeSet};

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

fn test_opts() -> CodegenOptions {
    CodegenOptions {
        title: "test".into(),
        auto_loop: false,
        diag_freeze: false,
        force_extended_jsr: false,
        _bank_size: 0,
        per_frame_silence: false,
        debug_init_draw: false,
        blink_intensity: false,
        exclude_ram_org: false,
        fast_wait: false,
        source_path: None,
        output_name: None,
        assets: vec![],
        const_values: BTreeMap::new(),
        const_arrays: BTreeMap::new(),
        const_string_arrays: BTreeSet::new(),
        mutable_arrays: BTreeSet::new(),
        structs: HashMap::new(),
        type_context: HashMap::new(),
        buffer_requirements: None,
        frame_groups: HashMap::new(),
        interleaved_frames: None,
    }
}

fn create_function(name: &str, body: Vec<Stmt>) -> Function {
    Function {
        name: name.to_string(),
        line: 1,
        params: vec![],
        frame_group: None,
        body,
    }
}

fn create_call_stmt(func_name: &str) -> Stmt {
    Stmt::Expr(
        Expr::Call(CallInfo {
            name: func_name.to_string(),
            source_line: 1,
            col: 1,
            args: vec![],
        }),
        1,
    )
}

fn create_ident_expr(name: &str) -> Expr {
    Expr::Ident(IdentInfo {
        name: name.to_string(),
        source_line: 1,
        col: 1,
    })
}

// ============================================================================
// CATEGORY: BASIC COMPILATION TESTS (10 tests)
// Tests that verify emit_asm() generates correct code without tree shaking
// (tree shaking happens in unifier phase, not tested here)
// ============================================================================

#[test]
fn test_compilation_includes_all_functions() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![])),
            Item::Function(create_function("unused_func", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // All functions should be present (no tree shaking at codegen level)
    assert!(asm.contains("MAIN:") || asm.contains("main:"));
    assert!(asm.contains("LOOP_BODY:") || asm.contains("loop:") || asm.contains("LOOP"));
    assert!(asm.contains("UNUSED_FUNC:") || asm.contains("unused_func:"));
}

#[test]
fn test_compilation_with_function_calls() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![
                create_call_stmt("helper"),
            ])),
            Item::Function(create_function("helper", vec![])),
            Item::Function(create_function("unused", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // All functions present (no tree shaking)
    assert!(asm.contains("HELPER:") || asm.contains("helper:"));
    assert!(asm.contains("UNUSED:") || asm.contains("unused:"));
    // Loop should call helper
    assert!(asm.contains("JSR HELPER") || asm.contains("jsr HELPER"));
}

#[test]
fn test_compilation_with_unused_variable() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![])),
            Item::GlobalLet {
                name: "unused_var".to_string(),
                value: Expr::Number(99),
                source_line: 2,
                type_annotation: None,
            },
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // Variable should be allocated (no tree shaking)
    assert!(asm.contains("UNUSED_VAR") || asm.contains("unused_var"));
}

#[test]
fn test_compilation_with_referenced_variable() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![
                Stmt::Expr(create_ident_expr("used_var"), 1),
            ])),
            Item::GlobalLet {
                name: "used_var".to_string(),
                value: Expr::Number(42),
                source_line: 1,
                type_annotation: None,
            },
            Item::GlobalLet {
                name: "unused_var".to_string(),
                value: Expr::Number(99),
                source_line: 2,
                type_annotation: None,
            },
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // Both variables should be present
    assert!(asm.contains("USED_VAR") || asm.contains("used_var"));
    assert!(asm.contains("UNUSED_VAR") || asm.contains("unused_var"));
}

#[test]
fn test_compilation_transitive_calls() {
    // main → loop → helper1 → helper2 (call chain)
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![
                create_call_stmt("helper1"),
            ])),
            Item::Function(create_function("helper1", vec![
                create_call_stmt("helper2"),
            ])),
            Item::Function(create_function("helper2", vec![])),
            Item::Function(create_function("unused", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // All functions should be present
    assert!(asm.contains("HELPER1:") || asm.contains("helper1:"));
    assert!(asm.contains("HELPER2:") || asm.contains("helper2:"));
    assert!(asm.contains("UNUSED:") || asm.contains("unused:"));
}

#[test]
fn test_compilation_setup_entrypoint() {
    // setup() is an entry point (never removed by tree shaking)
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![])),
            Item::Function(create_function("setup", vec![
                create_call_stmt("setup_helper"),
            ])),
            Item::Function(create_function("setup_helper", vec![])),
            Item::Function(create_function("unused", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // All functions present
    assert!(asm.contains("SETUP:") || asm.contains("setup:"));
    assert!(asm.contains("SETUP_HELPER:") || asm.contains("setup_helper:"));
    assert!(asm.contains("UNUSED:") || asm.contains("unused:"));
}

#[test]
fn test_compilation_entry_points_present() {
    // Entry points (main/loop/setup) always present
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![])),
            Item::Function(create_function("setup", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // All entry points should be present
    assert!(asm.contains("MAIN:") || asm.contains("main:"));
    assert!(asm.contains("LOOP") || asm.contains("loop"));
    assert!(asm.contains("SETUP:") || asm.contains("setup:"));
}

#[test]
fn test_compilation_const_values() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![
                Stmt::Expr(create_ident_expr("USED_CONST"), 1),
            ])),
            Item::Const {
                name: "USED_CONST".to_string(),
                value: Expr::Number(42),
                source_line: 1,
                type_annotation: None,
            },
            Item::Const {
                name: "UNUSED_CONST".to_string(),
                value: Expr::Number(99),
                source_line: 2,
                type_annotation: None,
            },
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // Both consts should appear
    assert!(asm.contains("USED_CONST") || asm.contains("used_const"));
    assert!(asm.contains("UNUSED_CONST") || asm.contains("unused_const"));
}

#[test]
fn test_basic_compilation_with_entrypoints() {
    let module = Module {
        items: vec![
            Item::Function(create_function("main", vec![])),
            Item::Function(create_function("loop", vec![])),
        ],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // Should contain basic setup and entry points
    assert!(!asm.is_empty());
    assert!(asm.contains("MAIN:") || asm.contains("main:"));
    assert!(asm.contains("LOOP") || asm.contains("loop"));
}

#[test]
fn test_empty_module_compilation() {
    let module = Module {
        items: vec![],
        meta: ModuleMeta::default(),
        imports: vec![],
    };
    
    let asm = emit_asm(&module, Target::Vectrex, &test_opts());
    
    // Should still generate valid (albeit minimal) ASM
    assert!(!asm.is_empty());
}
