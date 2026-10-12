//! `and` / `or` on the ARM targets: each gets labels of its own.
//!
//! They used numeric local labels (`1f`, `2f`), and `timer > 170 or (timer > 30 and
//! pressed)` jumped from the `or` to the nested `and`'s `1:` -- false when the left side
//! was true (the Return of the Jedi port's stage card never ended).

use vpy_codegen::{BankConfig, Target};

fn generate(src: &str, target: &Target) -> String {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    let module = vpy_unifier::unify_modules(modules, "main").expect("unify");
    let bank = if matches!(target, Target::PiTrex) { BankConfig::pitrex() } else { BankConfig::single_bank() };
    vpy_codegen::generate_from_module_with_target(&module, &bank, "T", &[], target).unwrap().asm_source
}

#[test]
fn nested_logic_ops_do_not_share_labels() {
    let src = "t = 0\np = 0\nr = 0\ndef main():\n    pass\ndef loop():\n    if t > 170 or (t > 30 and p):\n        r = 1\n    if (t or p) and (p or t):\n        r = 2\n";
    for target in [Target::Rp2350, Target::Uvm2, Target::PiTrex] {
        let asm = generate(src, &target);
        let code: Vec<&str> = asm.lines().map(|l| l.split('@').next().unwrap().trim()).collect();
        assert!(!code.iter().any(|l| l.ends_with(" 1f") || l.ends_with(" 2f") || *l == "1:" || l.starts_with("1:  mov")),
                "{target:?}: numeric labels left in and/or");
        // every branch of an and/or lands on its own label, defined exactly once
        for l in &code {
            if let Some(lbl) = l.split_whitespace().nth(1).filter(|t| t.starts_with(".Llg")) {
                let defs = code.iter().filter(|d| **d == format!("{lbl}:")).count();
                assert_eq!(defs, 1, "{target:?}: {lbl}");
            }
        }
    }
}
