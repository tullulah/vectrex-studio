//! Array element types on the ARM targets (rp2350, uvm2: Thumb-2; pitrex: ARM32).
//!
//! Every array element used to be a signed halfword on ARM whatever its declared
//! type: `xs: u8` took 2 bytes, and a value above 16 bits stored into any array
//! was truncated in silence (`strh`). Elements now follow the declared type as on
//! m6809 (u8/i8 = 1 byte, untyped/u16/i16 = 2), plus u32/i32 = 4 bytes, which
//! exist on the ARM targets only. Runtime values were checked on the uvm2 and
//! m6809 emulators; these tests pin the instructions.

use vpy_codegen::{BankConfig, Target};

const SRC: &str = "\
bs: u8 = [250, 7]
cs: i8 = [-100, 5]
us: u16 = [60000, 0]
hs = [-30000, 0]
ws: i32 = [100000, -70000]
const KW: i32 = [123456, -2]
r = 0

def rb(i):
    return bs[i]

def rc(i):
    return cs[i]

def ru(i):
    return us[i]

def rh(i):
    return hs[i]

def rw(i):
    return ws[i]

def wb(i, v):
    bs[i] = v

def ww(i, v):
    ws[i] += v

def get(arr, i):
    return arr[i]

def main():
    SET_INTENSITY(127)

def loop():
    r = rb(0) + rc(0) + ru(0) + rh(0) + rw(0) + get(ws, 1) + KW[0]
    wb(0, 1)
    ww(0, 1)
";

const ARM_TARGETS: [Target; 3] = [Target::Rp2350, Target::Uvm2, Target::PiTrex];

fn module(src: &str) -> vpy_parser::Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

fn generate(src: &str, target: &Target) -> Result<String, String> {
    let bank = if matches!(target, Target::PiTrex) { BankConfig::pitrex() } else { BankConfig::single_bank() };
    vpy_codegen::generate_from_module_with_target(&module(src), &bank, "T", &[], target)
        .map(|g| g.asm_source)
        .map_err(|e| e.to_string())
}

/// Instructions of function `label`, comments stripped, whitespace collapsed.
fn body(asm: &str, label: &str) -> Vec<String> {
    let start = asm.find(&format!("\n{label}:\n")).unwrap_or_else(|| panic!("no function {label}"));
    let rest = &asm[start + 1..];
    rest[..rest.find("\n    .ltorg").unwrap_or(rest.len())]
        .lines()
        .map(|l| l.split('@').next().unwrap().split_whitespace().collect::<Vec<_>>().join(" "))
        .filter(|l| !l.is_empty())
        .collect()
}

fn has(code: &[String], instr: &str) -> bool {
    code.iter().any(|l| l == instr)
}

#[test]
fn element_loads_and_stores_follow_the_declared_type() {
    for target in &ARM_TARGETS {
        let asm = generate(SRC, target).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        let expect = [
            ("RB", "ldrb r0, [r0]", None),
            ("RC", "ldrsb r0, [r0]", None),
            ("RU", "ldrh r0, [r0]", Some("lsl r1, r1, #1")),
            ("RH", "ldrsh r0, [r0]", Some("lsl r1, r1, #1")),
            ("RW", "ldr r0, [r0]", Some("lsl r1, r1, #2")),
            ("WB", "strb r0, [r1]", None),
            ("WW", "str r0, [r1]", Some("lsl r0, r0, #2")),
            // An array parameter takes the element type of the arrays passed to it.
            ("GET", "ldr r0, [r0]", Some("lsl r1, r1, #2")),
        ];
        for (func, access, scale) in expect {
            let code = body(&asm, func);
            assert!(has(&code, access), "{target:?} {func}: no `{access}` in {code:#?}");
            if let Some(scale) = scale {
                assert!(has(&code, scale), "{target:?} {func}: no `{scale}` in {code:#?}");
            } else {
                assert!(!code.iter().any(|l| l.starts_with("lsl")), "{target:?} {func}: byte index scaled");
            }
        }
        // Tables and initial values in the element's width.
        assert!(asm.contains(".word  123456"), "{target:?}: const i32 table");
        let init = |n: &str| asm.lines().any(|l| l.split_whitespace().collect::<Vec<_>>().join(" ").starts_with(n));
        assert!(init("strb r0, [r2, #1]") && init("str r0, [r2, #4]") && init("strh r0, [r2, #2]"), "{target:?}");
    }
}

#[test]
fn a_value_that_does_not_fit_its_array_is_an_error() {
    let src = "xs = [0, 0]\ndef main():\n    xs[0] = 100000\ndef loop():\n    pass\n";
    for target in &ARM_TARGETS {
        let err = generate(src, target).unwrap_err();
        assert!(err.contains("100000 stored into `XS` does not fit its i16 elements"), "{target:?}: {err}");
    }
}

#[test]
fn thirty_two_bit_arrays_are_rejected_on_m6809() {
    let err = generate(SRC, &Target::M6809).unwrap_err();
    assert!(err.contains("`WS: i32` — 32-bit integers exist on the ARM targets"), "{err}");
}
