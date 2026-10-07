//! Regression tests for m6809 codegen bugs that only surfaced at assembly time
//! (`Undefined symbol` / `Invalid decimal address`). Each case runs the real
//! Phase 2 → 3 → 5 path (parse, unify, generate) for a single-bank ROM and a
//! multibank ROM, plus the error cases. The end-to-end "it assembles and links"
//! check lives in `vpy_cli/tests/m6809_codegen_regressions.rs`.

use super::helpers::analyze_module_helpers;
use vpy_parser::Module;

const SINGLE_BANK: (usize, usize) = (32768, 0);
const MULTIBANK: (usize, usize) = (65536, 16384);

fn unify(src: &str) -> Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let module = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), module);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

fn generate(src: &str, (rom_size, bank_size): (usize, usize)) -> Result<String, String> {
    super::generate_m6809_asm(&unify(src), "TEST", rom_size, bank_size, &[])
}

fn generate_ok(src: &str, layout: (usize, usize)) -> String {
    generate(src, layout).unwrap_or_else(|e| panic!("codegen failed: {e}"))
}

/// True if `label:` is defined at the start of a line in `asm`.
fn defines_label(asm: &str, label: &str) -> bool {
    let want = format!("{label}:");
    asm.lines().any(|l| l.trim_end() == want || l.starts_with(&format!("{want} ")))
}

// ---------------------------------------------------------------------------
// Bug 1: builtins used only inside a `for` body were not tree-shaken in.
// ---------------------------------------------------------------------------

const FOR_BODY_SRC: &str = "\
def main():
    SET_INTENSITY(127)

def loop():
    for i in range(0, 3):
        DRAW_LINE(i, 0, 10, 10, 127)
        DRAW_CIRCLE(i, 0, 10)
";

#[test]
fn helpers_found_inside_for_body() {
    let needed = analyze_module_helpers(&unify(FOR_BODY_SRC));
    for helper in ["DRAW_LINE_WRAPPER", "DRAW_CIRCLE_RUNTIME"] {
        assert!(needed.contains(helper), "{helper} not detected inside for body: {needed:?}");
    }
}

#[test]
fn for_body_builtins_emit_helpers_single_bank() {
    let asm = generate_ok(FOR_BODY_SRC, SINGLE_BANK);
    assert!(defines_label(&asm, "DRAW_LINE_WRAPPER"), "DRAW_LINE_WRAPPER not emitted");
    assert!(defines_label(&asm, "DRAW_CIRCLE_RUNTIME"), "DRAW_CIRCLE_RUNTIME not emitted");
}

#[test]
fn for_body_builtins_emit_helpers_multibank() {
    let asm = generate_ok(FOR_BODY_SRC, MULTIBANK);
    assert!(defines_label(&asm, "DRAW_LINE_WRAPPER"), "DRAW_LINE_WRAPPER not emitted");
    assert!(defines_label(&asm, "DRAW_CIRCLE_RUNTIME"), "DRAW_CIRCLE_RUNTIME not emitted");
}

/// Every statement kind that can hold a builtin call must be scanned.
#[test]
fn helpers_found_in_every_statement_kind() {
    let src = "\
xs = [0, 0, 0]

def main():
    SET_INTENSITY(127)

def pick(v):
    return RAND()

def loop():
    for v in xs:
        PRINT_NUMBER(0, 0, v)
    i = 0
    while i < 2:
        DRAW_RECT(0, 0, 10, 10)
        i += 1
    switch i:
        case 1:
            DRAW_VECTOR_3D(\"ship\", 0, 0, 0, 0, 0)
        default:
            PRINT_TEXT(0, 0, \"X\")
    xs[RAND_RANGE(0, 2)] = 1
    i -= SQRT(i)
";
    let needed = analyze_module_helpers(&unify(src));
    for helper in [
        "PRINT_NUMBER",      // for-in body
        "DRAW_RECT_RUNTIME", // while body
        "DRAW_VECTOR_3D",    // switch case
        "PRINT_TEXT",        // switch default
        "RAND_HELPER",       // return value
        "RAND_RANGE_HELPER", // index expression of an assignment target
        "SQRT_HELPER",       // compound assignment value
    ] {
        assert!(needed.contains(helper), "{helper} not detected: {needed:?}");
    }
}

// ---------------------------------------------------------------------------
// Bug 2: J1_X()/J1_Y() (and J2) used only in an `if` comparison.
// ---------------------------------------------------------------------------

const JOY_COND_SRC: &str = "\
def main():
    SET_INTENSITY(127)

def loop():
    if J1_X() > 20:
        PRINT_TEXT(0, 0, \"R\")
    elif J1_Y() < -20:
        PRINT_TEXT(0, 0, \"D\")
    while J2_X() > 20 and J2_Y() > 0:
        PRINT_TEXT(0, 0, \"X\")
";

#[test]
fn joystick_builtins_found_in_conditions() {
    let needed = analyze_module_helpers(&unify(JOY_COND_SRC));
    for helper in ["J1X_BUILTIN", "J1Y_BUILTIN", "J2X_BUILTIN", "J2Y_BUILTIN"] {
        assert!(needed.contains(helper), "{helper} not detected in a condition: {needed:?}");
    }
}

#[test]
fn joystick_conditions_emit_builtins_single_bank() {
    let asm = generate_ok(JOY_COND_SRC, SINGLE_BANK);
    for label in ["J1X_BUILTIN", "J1Y_BUILTIN", "J2X_BUILTIN", "J2Y_BUILTIN"] {
        assert!(defines_label(&asm, label), "{label} not emitted");
    }
}

#[test]
fn joystick_conditions_emit_builtins_multibank() {
    let asm = generate_ok(JOY_COND_SRC, MULTIBANK);
    for label in ["J1X_BUILTIN", "J1Y_BUILTIN", "J2X_BUILTIN", "J2Y_BUILTIN"] {
        assert!(defines_label(&asm, label), "{label} not emitted");
    }
}

// ---------------------------------------------------------------------------
// Bug 3: an unused global array referenced a RAM pointer that was never
// allocated (`STX VAR_XS`). Array names now evaluate to their data label.
// ---------------------------------------------------------------------------

const UNUSED_ARRAY_SRC: &str = "\
xs = [1, 2, 3]
const YS = [4, 5]

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_TEXT(0, 0, \"HI\")
";

fn assert_no_array_pointer_vars(asm: &str) {
    for sym in ["VAR_XS", "VAR_YS"] {
        let used = asm.lines().any(|l| {
            l.split(|c: char| !(c.is_ascii_alphanumeric() || c == '_')).any(|tok| tok == sym)
        });
        assert!(!used, "{sym} (array pointer variable) still referenced");
    }
    assert!(asm.contains("VAR_XS_DATA"), "mutable array RAM block missing");
}

#[test]
fn unused_array_has_no_pointer_variable_single_bank() {
    assert_no_array_pointer_vars(&generate_ok(UNUSED_ARRAY_SRC, SINGLE_BANK));
}

#[test]
fn unused_array_has_no_pointer_variable_multibank() {
    assert_no_array_pointer_vars(&generate_ok(UNUSED_ARRAY_SRC, MULTIBANK));
}

#[test]
fn array_name_evaluates_to_its_base_address() {
    let src = "\
xs = [1, 2, 3]
const YS = [4, 5]
total = 0

def main():
    SET_INTENSITY(127)

def loop():
    for v in YS:
        total = total + v
    for v in xs:
        total = total + v
";
    let asm = generate_ok(src, SINGLE_BANK);
    assert!(asm.contains("LDD #ARRAY_YS_DATA"), "const array base not loaded as immediate");
    assert!(asm.contains("LDD #VAR_XS_DATA"), "mutable array base not loaded as immediate");
}

#[test]
fn u8_array_copy_is_sized_in_bytes() {
    let src = "\
bs: u8 = [10, 20, 30]

def main():
    bs[0] = 1

def loop():
    pass
";
    let asm = generate_ok(src, SINGLE_BANK);
    assert!(asm.contains("LDY #3        ; Number of bytes"), "u8 array copy must move 3 bytes:\n{asm}");
}

#[test]
fn assigning_a_whole_global_array_is_an_error() {
    let src = "\
xs = [1, 2, 3]

def main():
    xs = 5

def loop():
    pass
";
    let err = generate(src, SINGLE_BANK).expect_err("rebinding a global array must fail").to_lowercase();
    assert!(err.contains("cannot assign to global array 'xs'"), "unexpected error: {err}");
}

// ---------------------------------------------------------------------------
// Bug 4: len() was a stub returning 0.
// ---------------------------------------------------------------------------

const LEN_SRC: &str = "\
xs = [1, 2, 3]
const YS = [4, 5, 6, 7]

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, len(xs) + len(YS))
";

#[test]
fn len_of_global_arrays_single_bank() {
    let asm = generate_ok(LEN_SRC, SINGLE_BANK);
    assert!(asm.contains("LDD #ARRAY_XS_LEN"), "len(xs) must load ARRAY_XS_LEN");
    assert!(asm.contains("LDD #ARRAY_YS_LEN"), "len(YS) must load ARRAY_YS_LEN");
    assert!(asm.contains("ARRAY_XS_LEN         EQU 3"));
    assert!(asm.contains("ARRAY_YS_LEN         EQU 4"));
}

#[test]
fn len_of_global_arrays_multibank() {
    let asm = generate_ok(LEN_SRC, MULTIBANK);
    assert!(asm.contains("LDD #ARRAY_XS_LEN"));
    assert!(asm.contains("LDD #ARRAY_YS_LEN"));
}

#[test]
fn len_of_non_array_is_an_error() {
    let src = "\
score = 3

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, len(score))
";
    let err = generate(src, SINGLE_BANK).expect_err("len(scalar) must fail").to_lowercase();
    assert!(err.contains("len(score)") && err.contains("not a global array"), "unexpected error: {err}");
}

#[test]
fn len_of_parameter_is_an_error() {
    let src = "\
def count(a):
    return len(a)

def main():
    SET_INTENSITY(127)

def loop():
    pass
";
    let err = generate(src, MULTIBANK).expect_err("len(param) must fail").to_lowercase();
    assert!(err.contains("len(a)") && err.contains("parameter"), "unexpected error: {err}");
}

#[test]
fn len_of_expression_is_an_error() {
    let src = "\
def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, len(\"abc\"))
";
    let err = generate(src, SINGLE_BANK).expect_err("len(literal) must fail");
    assert!(err.contains("len()") && err.contains("global array"), "unexpected error: {err}");
}
