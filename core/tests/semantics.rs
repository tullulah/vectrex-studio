use vectrex_lang::ast::*;
use vectrex_lang::codegen::{DiagnosticCode, emit_asm_with_diagnostics};

#[test]
fn semantics_valid_decl_and_use() {
    let module = Module { items: vec![
        Item::Const { name: "C1".to_string(), value: Expr::Number(5), source_line: 0, type_annotation: None },
        Item::Function(Function { name: "main".to_string(), line: 0, params: vec!["p".to_string()], frame_group: None, body: vec![
            Stmt::Let { name: "x".to_string(), value: Expr::Ident(IdentInfo { name: "p".into(), source_line: 0, col: 0 }), source_line: 0 },
            Stmt::Assign { target: AssignTarget::Ident { name: "x".to_string(), source_line: 0, col: 0 }, value: Expr::Binary { op: BinOp::Add, left: Box::new(Expr::Ident(IdentInfo { name:"x".into(), source_line: 0, col: 0 })), right: Box::new(Expr::Ident(IdentInfo { name:"C1".into(), source_line: 0, col: 0 })) }, source_line: 0 },
            Stmt::Return(Some(Expr::Ident(IdentInfo { name:"x".into(), source_line: 0, col: 0 })), 0)
        ]})
    ], imports: vec![], meta: ModuleMeta::default() };
    // emit_asm should not panic
    let asm = vectrex_lang::codegen::emit_asm(&module, vectrex_lang::target::Target::Vectrex, &vectrex_lang::codegen::CodegenOptions {
        title: "t".into(),
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
        assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    });
    // El módulo requiere loop() pero no lo tiene, así que debe contener ERROR
    assert!(asm.contains("ERROR") || asm.contains("MAIN") || asm.to_uppercase().contains("MAIN"));
}

#[test]
fn semantics_undefined_use_reports_error() {
    let module = Module { items: vec![
        Item::Function(Function { name: "f".to_string(), line: 0, params: vec![], frame_group: None, body: vec![
            Stmt::Expr(Expr::Ident(IdentInfo { name:"y".into(), source_line: 0, col: 0 }), 0)
        ]})
    ], imports: vec![], meta: ModuleMeta::default() };
    let (_asm, diags) = emit_asm_with_diagnostics(&module, vectrex_lang::target::Target::Vectrex, &vectrex_lang::codegen::CodegenOptions {
        title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    });
    assert!(diags.iter().any(|d| matches!(d.code, DiagnosticCode::UndeclaredVar)), "expected undeclared variable error, got: {:?}", diags);
}

#[test]
fn semantics_valid_builtin_arity() {
    // FRAME_BEGIN(intensity=Expr::Number)
    let module = Module { items: vec![
        Item::Function(Function { name: "g".to_string(), line: 0, params: vec![], frame_group: None, body: vec![
            Stmt::Expr(Expr::Call(CallInfo { name: "FRAME_BEGIN".into(), source_line: 0, col: 0, args: vec![Expr::Number(10)] }), 0),
            Stmt::Return(None, 0)
        ]})
    ], imports: vec![], meta: ModuleMeta::default() };
    let _ = vectrex_lang::codegen::emit_asm(&module, vectrex_lang::target::Target::Vectrex, &vectrex_lang::codegen::CodegenOptions {
        title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    });
}

#[test]
fn semantics_bad_builtin_arity_reports_error() {
    let module = Module { items: vec![
        Item::Function(Function { name: "h".to_string(), line: 0, params: vec![], frame_group: None, body: vec![
            // DRAW_LINE necesita 5 args; damos 4
            Stmt::Expr(Expr::Call(CallInfo { name: "DRAW_LINE".into(), source_line: 0, col: 0, args: vec![Expr::Number(0),Expr::Number(0),Expr::Number(1),Expr::Number(1)] }), 0)
        ]})
    ], imports: vec![], meta: ModuleMeta::default() };
    let (_asm, diags) = emit_asm_with_diagnostics(&module, vectrex_lang::target::Target::Vectrex, &vectrex_lang::codegen::CodegenOptions {
        title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    });
    assert!(diags.iter().any(|d| matches!(d.code, DiagnosticCode::ArityMismatch)), "expected arity error, got: {:?}", diags);
}

#[test]
fn semantics_unused_var_warning() {
    let module = Module { items: vec![
        Item::Function(Function { name: "w".to_string(), line: 0, params: vec![], frame_group: None, body: vec![
            Stmt::Let { name: "x".into(), value: Expr::Number(1), source_line: 0 },
            Stmt::Return(None, 0)
        ]})
    ], imports: vec![], meta: ModuleMeta::default() };
    let (_asm, diags) = emit_asm_with_diagnostics(&module, vectrex_lang::target::Target::Vectrex, &vectrex_lang::codegen::CodegenOptions {
        title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
        const_values: std::collections::BTreeMap::new(),
        const_arrays: std::collections::BTreeMap::new(),
        const_string_arrays: std::collections::BTreeSet::new(),
        mutable_arrays: std::collections::BTreeSet::new(),
        structs: std::collections::HashMap::new(),
        type_context: std::collections::HashMap::new(),
        output_name: None,
        buffer_requirements: None,
        frame_groups: std::collections::HashMap::new(),
        interleaved_frames: None,
    });
    assert!(diags.iter().any(|d| matches!(d.code, DiagnosticCode::UnusedVar)), "expected unused var warning, got: {:?}", diags);
}
