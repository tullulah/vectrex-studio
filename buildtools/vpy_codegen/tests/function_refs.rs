//! Function references and calls through a variable (ARM targets).
//!
//! `handler = twice` stores the function's address; `f(x, 1)` with `f` a
//! parameter, local or global calls what it holds (`blx`). Run on the uvm2
//! emulator: `apply(twice, 20)` returned 41. m6809 cannot: its static frames are
//! overlaid by call graph, so the callee must be known at compile time.

use vpy_codegen::{BankConfig, Target};

const SRC: &str = "\
handler = 0
r = 0

def twice(a, b):
    return a * 2 + b

def apply(f, x):
    return f(x, 1)

def main():
    handler = twice
    r = apply(handler, 20) + handler(1, 2)

def loop():
    pass
";

fn generate(src: &str, target: &Target) -> Result<String, String> {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    let module = vpy_unifier::unify_modules(modules, "main").expect("unify");
    let bank = if matches!(target, Target::PiTrex) { BankConfig::pitrex() } else { BankConfig::single_bank() };
    vpy_codegen::generate_from_module_with_target(&module, &bank, "T", &[], target)
        .map(|g| g.asm_source)
        .map_err(|e| e.to_string())
}

fn instrs(asm: &str) -> Vec<String> {
    asm.lines()
        .map(|l| l.split('@').next().unwrap().split_whitespace().collect::<Vec<_>>().join(" "))
        .filter(|l| !l.is_empty())
        .collect()
}

#[test]
fn addresses_and_indirect_calls_on_arm() {
    for target in [Target::Rp2350, Target::Uvm2, Target::PiTrex] {
        let asm = generate(SRC, &target).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        let code = instrs(&asm);
        assert!(code.iter().any(|l| l == "ldr r0, =TWICE"), "{target:?}: the function's address");
        // Through the parameter (frame slot) and through the global.
        assert!(code.iter().any(|l| l.starts_with("ldr r12, [r7, #")), "{target:?}: f from the frame");
        assert_eq!(code.iter().filter(|l| *l == "blx r12").count(), 2, "{target:?}");
        let thumb = code.iter().any(|l| l == "orr r12, r12, #1");
        assert_eq!(thumb, !matches!(target, Target::PiTrex), "{target:?}: Thumb bit only on Thumb targets");
    }
}

#[test]
fn m6809_refuses_them_with_the_line() {
    let err = generate(SRC, &Target::M6809).unwrap_err();
    assert!(err.contains("line 8: `f(...)` calls the function held in a variable"), "{err}");
    assert!(err.contains("line 11: `twice` names a function as a value"), "{err}");
}
