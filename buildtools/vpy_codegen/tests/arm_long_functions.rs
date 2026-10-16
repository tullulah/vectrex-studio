//! Long functions on the ARM targets, and the runtime's sqrt.
//!
//! `ldr rN, =value` reaches a literal pool about 4 KB away, and a function had one
//! pool, at its end: a long `game_main` (the Return of the Jedi port) failed to
//! assemble with "offset out of range". Islands -- a branch over a `.ltorg` -- now go
//! between statements. And vpy_sqrt returned 46340 for every n >= 46340.

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
fn long_bodies_get_literal_pool_islands() {
    let mut src = String::from("a = 0\ndef main():\n");
    for i in 0..400 {
        src.push_str(&format!("    a = a + {}\n", 100000 + i));
    }
    src.push_str("def loop():\n    pass\n");
    for target in [Target::Rp2350, Target::Uvm2, Target::PiTrex] {
        let asm = generate(&src, &target);
        let lines: Vec<&str> = asm.lines().map(|l| l.split('@').next().unwrap().trim()).collect();
        let islands: Vec<usize> = lines.iter().enumerate().filter(|(_, l)| l.starts_with("b .Lpool_skip_") || l.starts_with("b       .Lpool_skip_")).map(|(i, _)| i).collect();
        assert!(!islands.is_empty(), "{target:?}: no island in a long body");
        for i in islands {
            // the branch jumps over the pool and lands right after it, on code
            assert_eq!(lines[i + 1], ".ltorg", "{target:?}");
            assert!(lines[i + 2].starts_with(".Lpool_skip_") && lines[i + 2].ends_with(':'), "{target:?}");
        }
    }
}

#[test]
fn sqrt_searches_the_whole_int32_range() {
    let asm = generate("r = 0\ndef main():\n    r = sqrt(100000)\ndef loop():\n    pass\n", &Target::Uvm2);
    let body = &asm[asm.find("vpy_sqrt:").unwrap()..];
    let body = &body[..body.find(".ltorg").unwrap()];
    assert!(body.contains("=46341"), "the search bound");
    assert!(!body.contains("mov     r0, r6"), "the old early return of 46340");
}
