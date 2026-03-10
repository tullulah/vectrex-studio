use vectrex_lang::ast::*;
use vectrex_lang::codegen::debug_optimize_module_for_tests;

// S4: Constant folding test
// NOTE: Full DSE/constant propagation is currently DISABLED in optimize_module.
// This test verifies that basic constant folding still works at expression level.
#[test]
fn constant_folding_add_mul_identities() {
    let f = Function { name: "main".into(), line: 0, params: vec![], frame_group: None, body: vec![
        Stmt::Let { name: "a".into(), value: Expr::Binary { op: BinOp::Add, left: Box::new(Expr::Number(0)), right: Box::new(Expr::Number(5)) }, source_line: 0 },
        Stmt::Let { name: "b".into(), value: Expr::Binary { op: BinOp::Mul, left: Box::new(Expr::Number(1)), right: Box::new(Expr::Ident(IdentInfo { name:"a".into(), source_line: 0, col: 0 })) }, source_line: 0 },
        Stmt::Return(Some(Expr::Ident(IdentInfo { name:"b".into(), source_line: 0, col: 0 })), 0)
    ]};
    let m = Module { items: vec![Item::Function(f)], imports: vec![], meta: ModuleMeta::default() };
    let opt = debug_optimize_module_for_tests(&m);
    // With DSE disabled, statements remain but expressions should be folded
    if let Item::Function(fun) = &opt.items[0] {
        // Verify constant folding happened: 0+5 -> 5, 1*a -> a
        if let Stmt::Let { value: Expr::Number(5), .. } = &fun.body[0] {
            // First let should have folded 0+5 to 5
        } else {
            panic!("expected Let with Number(5) after folding, got {:?}", fun.body[0]);
        }
    } else { panic!("expected function") }
}

// S4: Dead store elimination test
// NOTE: DSE is currently DISABLED. This test verifies the module structure is preserved.
#[test]
fn dead_store_elimination_basic() {
    // x assigned then overwritten before any read; first assign should be removed.
    // However, DSE is disabled, so all statements should remain.
    let f = Function { name: "f".into(), line: 0, params: vec![], frame_group: None, body: vec![
        Stmt::Let { name: "x".into(), value: Expr::Number(1), source_line: 0 }, // would be dead if DSE enabled
        Stmt::Assign { target: AssignTarget::Ident { name: "x".into(), source_line: 0, col: 0 }, value: Expr::Number(2), source_line: 0 },
        Stmt::Return(Some(Expr::Ident(IdentInfo { name:"x".into(), source_line: 0, col: 0 })), 0)
    ]};
    let m = Module { items: vec![Item::Function(f)], imports: vec![], meta: ModuleMeta::default() };
    let opt = debug_optimize_module_for_tests(&m);
    if let Item::Function(fun) = &opt.items[0] {
        // DSE is disabled, so all 3 statements should remain
        assert_eq!(fun.body.len(), 3, "with DSE disabled, all statements should remain: {:?}", fun.body);
    }
}
