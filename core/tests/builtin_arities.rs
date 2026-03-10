//! Test de regresión para la tabla centralizada BUILTIN_ARITIES.
//! Para cada builtin: una llamada con aridad correcta NO debe generar ArityMismatch; una con aridad incorrecta SÍ debe.

use vectrex_lang::ast::*;
use vectrex_lang::codegen::{emit_asm_with_diagnostics, DiagnosticCode, CodegenOptions};
use vectrex_lang::target::Target;

#[derive(Clone, Copy)]
struct Case { name: &'static str, ok_arity: usize, bad_arity: usize }

#[test]
fn builtin_arities_stable() {
    let cases = [
        Case { name: "PRINT_TEXT", ok_arity: 3, bad_arity: 2 },
        Case { name: "MOVE_TO", ok_arity: 2, bad_arity: 1 },
        Case { name: "DRAW_TO", ok_arity: 2, bad_arity: 3 },
        Case { name: "DRAW_LINE", ok_arity: 5, bad_arity: 4 },
        Case { name: "DRAW_VL", ok_arity: 2, bad_arity: 1 },
        Case { name: "FRAME_BEGIN", ok_arity: 1, bad_arity: 0 },
        Case { name: "VECTOR_PHASE_BEGIN", ok_arity: 0, bad_arity: 1 },
        Case { name: "SET_ORIGIN", ok_arity: 0, bad_arity: 1 },
        Case { name: "SET_INTENSITY", ok_arity: 1, bad_arity: 2 },
        Case { name: "WAIT_RECAL", ok_arity: 0, bad_arity: 1 },
        Case { name: "PLAY_MUSIC1", ok_arity: 0, bad_arity: 1 },
        Case { name: "DBG_STATIC_VL", ok_arity: 0, bad_arity: 1 },
    ];

    for c in cases {        
        // Construir función main con llamada de aridad correcta
        let ok_args: Vec<Expr> = (0..c.ok_arity).map(|i| Expr::Number(i as i32)).collect();
        let ok_module = Module { items: vec![Item::Function(Function { name: "main".into(), line: 0, params: vec![], frame_group: None, body: vec![
            Stmt::Expr(Expr::Call(CallInfo { name: c.name.into(), source_line: 0, col: 0, args: ok_args }), 0)
        ]})], imports: vec![], meta: ModuleMeta::default() };
        let (_asm, diags) = emit_asm_with_diagnostics(&ok_module, Target::Vectrex, &CodegenOptions { title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
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
        assert!(diags.iter().all(|d| d.code != DiagnosticCode::ArityMismatch), "{} deberia aceptar {} args: {:?}", c.name, c.ok_arity, diags);

        // Construir función main con llamada de aridad incorrecta
        let bad_args: Vec<Expr> = (0..c.bad_arity).map(|i| Expr::Number(i as i32)).collect();
        let bad_module = Module { items: vec![Item::Function(Function { name: "main".into(), line: 0, params: vec![], frame_group: None, body: vec![
            Stmt::Expr(Expr::Call(CallInfo { name: c.name.into(), source_line: 0, col: 0, args: bad_args }), 0)
        ]})], imports: vec![], meta: ModuleMeta::default() };
        let (_asm_bad, diags_bad) = emit_asm_with_diagnostics(&bad_module, Target::Vectrex, &CodegenOptions { title: "t".into(), auto_loop: false, diag_freeze: false, force_extended_jsr: false, _bank_size: 0, per_frame_silence: false, debug_init_draw: false, blink_intensity: false, exclude_ram_org: false, fast_wait: false, source_path: None, assets: vec![],
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
        assert!(diags_bad.iter().any(|d| d.code == DiagnosticCode::ArityMismatch), "{} deberia rechazar {} args (tabla espera {}): {:?}", c.name, c.bad_arity, c.ok_arity, diags_bad);
    }
}
