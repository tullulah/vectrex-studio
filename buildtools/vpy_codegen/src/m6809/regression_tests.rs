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

// ---------------------------------------------------------------------------
// Bug 5: `for v in arr` always stepped 2 bytes and zero-extended, whatever the
// array's type; an 8-bit array was read as garbage pairs.
// ---------------------------------------------------------------------------

const FOR_IN_TYPED_SRC: &str = "\
bytes: u8 = [1, 2, 200]
signed: i8 = [-1, 5]
words = [1000, -2000]
total = 0

def main():
    SET_INTENSITY(127)

def loop():
    for b in bytes:
        total = total + b
    for s in signed:
        total = total + s
    for w in words:
        total = total + w
    PRINT_NUMBER(0, 0, total)
";

/// The element-load sequence of each `for .. in` loop, in source order.
fn for_in_loads(asm: &str) -> Vec<String> {
    asm.split("; forin start")
        .skip(1)
        .map(|chunk| chunk.split("; VPy_LINE").next().unwrap_or("").to_string())
        .collect()
}

fn assert_for_in_strides(asm: &str) {
    let loops = for_in_loads(asm);
    assert_eq!(loops.len(), 3, "three for-in loops expected");
    let (u8_loop, i8_loop, i16_loop) = (&loops[0], &loops[1], &loops[2]);
    for (name, l) in [("u8", u8_loop), ("i8", i8_loop)] {
        assert!(!l.contains("ASLB"), "{name} loop must step 1 byte:\n{l}");
        assert!(l.contains("LDB ,X"), "{name} loop must load one byte:\n{l}");
    }
    assert!(u8_loop.contains("CLRA"), "u8 elements are zero-extended:\n{u8_loop}");
    assert!(i8_loop.contains("SEX"), "i8 elements are sign-extended:\n{i8_loop}");
    assert!(i16_loop.contains("ASLB") && i16_loop.contains("LDD ,X"), "16-bit loop steps 2 bytes:\n{i16_loop}");
}

#[test]
fn for_in_uses_element_size_single_bank() {
    assert_for_in_strides(&generate_ok(FOR_IN_TYPED_SRC, SINGLE_BANK));
}

#[test]
fn for_in_uses_element_size_multibank() {
    assert_for_in_strides(&generate_ok(FOR_IN_TYPED_SRC, MULTIBANK));
}

#[test]
fn i8_index_is_sign_extended() {
    let src = "\
signed: i8 = [-1, 5]

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, signed[0])
";
    let asm = generate_ok(src, SINGLE_BANK);
    assert!(asm.contains("LDB ,X") && asm.contains("SEX                 ; i8: sign-extend"), "{asm}");
}

#[test]
fn for_in_over_non_array_is_an_error() {
    let src = "\
n = 3

def main():
    SET_INTENSITY(127)

def loop():
    for v in n:
        pass
";
    let err = generate(src, SINGLE_BANK).expect_err("for-in over a scalar must fail");
    assert!(err.contains("line 7") && err.contains("`N` is not an array"), "unexpected error: {err}");
}

#[test]
fn for_in_over_parameter_is_an_error() {
    let src = "\
def total(a):
    t = 0
    for v in a:
        t = t + v
    return t

def main():
    SET_INTENSITY(127)

def loop():
    pass
";
    let err = generate(src, MULTIBANK).expect_err("for-in over a parameter must fail");
    assert!(err.contains("line 3") && err.contains("parameter") && err.contains("range(0, n)"), "unexpected error: {err}");
}

// ---------------------------------------------------------------------------
// Bug 6: indexing an array parameter emitted `ARRAY_<PARAM>_DATA` (undefined).
// Arrays are passed as their base address; the parameter is a pointer whose
// element type comes from the arrays passed at the call sites.
// ---------------------------------------------------------------------------

const ARRAY_PARAM_SRC: &str = "\
words = [10, 20, 30]
bytes: u8 = [1, 2, 3]
total = 0

def sum_words(arr):
    return arr[0] + arr[2]

def first_byte(b):
    return b[0]

def forward(b):
    b[1] = 7
    return first_byte(b)

def main():
    SET_INTENSITY(127)

def loop():
    total = sum_words(words) + forward(bytes)
    PRINT_NUMBER(0, 0, total)
";

/// Body of the function at `label:` up to its RTS.
fn body<'a>(asm: &'a str, label: &str) -> &'a str {
    let start = asm.find(&format!("\n{label}:\n")).unwrap_or_else(|| panic!("{label} not defined"));
    let rest = &asm[start..];
    &rest[..rest.find("RTS").unwrap_or(rest.len())]
}

fn assert_array_params(asm: &str) {
    assert!(!asm.contains("ARRAY_ARR_DATA") && !asm.contains("ARRAY_B_DATA"), "parameter indexed as a global array");
    let words = body(asm, "SUM_WORDS");
    assert!(words.contains("ADDD >VAR_ARG0") && words.contains("ASLB") && words.contains("LDD ,X"),
        "16-bit elements through the pointer:\n{words}");
    // u8 array passed to forward(), which forwards it to first_byte(): both 1-byte.
    for f in ["FIRST_BYTE", "FORWARD"] {
        let b = body(asm, f);
        assert!(b.contains("ADDD >VAR_ARG0") && !b.contains("ASLB"), "{f}: 1-byte stride:\n{b}");
    }
    assert!(body(asm, "FIRST_BYTE").contains("LDB ,X"), "u8 load");
    assert!(body(asm, "FORWARD").contains("STB ,X"), "u8 store");
    // the call site passes the base address
    assert!(asm.contains("LDD #VAR_WORDS_DATA") && asm.contains("LDD #VAR_BYTES_DATA"));
}

#[test]
fn array_parameters_single_bank() {
    assert_array_params(&generate_ok(ARRAY_PARAM_SRC, SINGLE_BANK));
}

#[test]
fn array_parameters_multibank() {
    assert_array_params(&generate_ok(ARRAY_PARAM_SRC, MULTIBANK));
}

#[test]
fn array_parameter_with_mixed_element_types_is_an_error() {
    let src = "\
words = [10, 20]
bytes: u8 = [1, 2]

def first(a):
    return a[0]

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, first(words) + first(bytes))
";
    let err = generate(src, SINGLE_BANK).expect_err("mixed element types must fail");
    assert!(err.contains("parameter `a`") && err.contains("`WORDS` (i16)") && err.contains("`BYTES` (u8)"),
        "unexpected error: {err}");
}

#[test]
fn indexing_a_scalar_is_an_error() {
    let src = "\
n = 3

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, n[1])
";
    let err = generate(src, SINGLE_BANK).expect_err("indexing a scalar must fail");
    assert!(err.contains("line 7") && err.contains("`N` is not an array"), "unexpected error: {err}");
}

#[test]
fn parameter_named_like_a_u8_global_keeps_the_global_8_bit() {
    // A parameter used to register its 16-bit size under its own name, which
    // turned every access to the u8 global of the same name into a 16-bit one.
    let src = "\
level: u8 = 0

def show(level):
    PRINT_NUMBER(0, 0, level)

def main():
    level = 2

def loop():
    show(level)
";
    let asm = generate_ok(src, SINGLE_BANK);
    assert!(asm.contains("STB VAR_LEVEL"), "u8 global must stay 8-bit:\n{asm}");
}

// ---------------------------------------------------------------------------
// Bug 7: `const B = A * 2` was never initialised (RAM slot, no store).
// ---------------------------------------------------------------------------

const CONST_FOLD_SRC: &str = "\
const A = 10
const B = A * 2 + 4
const MASK = ~B & 0xFF

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(B, MASK, B + MASK)
";

fn assert_consts_folded(asm: &str) {
    assert!(asm.contains("LDD #24  ; const B"), "B must fold to 24");
    assert!(asm.contains(&format!("LDD #{}  ; const MASK", !24i64 & 0xFF)), "MASK must fold");
    assert!(!asm.contains("VAR_B ") && !asm.contains("VAR_MASK"), "folded consts need no RAM");
    let sum = 24 + (!24i64 & 0xFF);
    assert!(asm.contains(&format!("LDD #{sum}\n")), "a constant argument expression folds to {sum}");
}

#[test]
fn const_expressions_fold_single_bank() {
    assert_consts_folded(&generate_ok(CONST_FOLD_SRC, SINGLE_BANK));
}

#[test]
fn const_expressions_fold_multibank() {
    assert_consts_folded(&generate_ok(CONST_FOLD_SRC, MULTIBANK));
}

#[test]
fn unfoldable_const_is_an_error_with_line() {
    let src = "\
speed = 2

const B = speed * 2

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, B)
";
    let err = generate(src, SINGLE_BANK).expect_err("a const of a variable must fail");
    assert!(err.contains("line 3") && err.contains("`B`") && err.contains("not a const"), "unexpected error: {err}");
}

// ---------------------------------------------------------------------------
// Bug 8: every wait(n > 10) defined the same `WAIT_LOOP` label.
// ---------------------------------------------------------------------------

const WAIT_SRC: &str = "\
const PAUSE = 300

def main():
    SET_INTENSITY(127)
    wait(20)
    wait(PAUSE)

def loop():
    wait(2)
";

fn assert_unique_wait_labels(asm: &str) {
    let labels: Vec<&str> = asm
        .lines()
        .filter(|l| l.starts_with("WAIT_LOOP") && l.trim_end().ends_with(':'))
        .collect();
    assert_eq!(labels.len(), 2, "one loop per wait(n > 10): {labels:?}");
    assert_ne!(labels[0], labels[1], "wait loop labels must be unique");
    assert!(asm.contains("LDD #300"), "a const frame count (16-bit) is accepted");
}

#[test]
fn wait_labels_unique_single_bank() {
    assert_unique_wait_labels(&generate_ok(WAIT_SRC, SINGLE_BANK));
}

#[test]
fn wait_labels_unique_multibank() {
    assert_unique_wait_labels(&generate_ok(WAIT_SRC, MULTIBANK));
}

#[test]
fn wait_with_variable_count_is_an_error() {
    let src = "\
n = 20

def main():
    wait(n)

def loop():
    pass
";
    let err = generate(src, SINGLE_BANK).expect_err("wait(variable) must fail");
    assert!(err.contains("wait() needs a constant frame count"), "unexpected error: {err}");
}

// ---------------------------------------------------------------------------
// PLAY_SAMPLE / SAMPLE_POS: ARM-only, a clear target error on m6809.
// ---------------------------------------------------------------------------

#[test]
fn samples_are_a_target_error() {
    let src = "\
def main():
    PLAY_SAMPLE(\"voice\")

def loop():
    PRINT_NUMBER(0, 0, SAMPLE_POS(25))
";
    for layout in [SINGLE_BANK, MULTIBANK] {
        let err = generate(src, layout).expect_err("samples must fail on m6809");
        assert!(err.contains("line 2: PLAY_SAMPLE is not supported on m6809"), "unexpected error: {err}");
        assert!(err.contains("line 5: SAMPLE_POS is not supported on m6809"), "unexpected error: {err}");
        assert!(err.contains("rp2350 or pitrex"), "unexpected error: {err}");
    }
}

#[test]
fn parameter_shadows_a_const_of_the_same_name() {
    // Names are case-insensitive: parameter `b` and `const B` are the same name.
    // Inside the function the parameter wins; it used to be replaced by B's value.
    let src = "\
const B = 32
bytes: u8 = [1, 2, 3]

def get(b, i):
    return b[i]

def fwd(b):
    return get(b, 2)

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_NUMBER(0, 0, fwd(bytes) + B)
";
    for layout in [SINGLE_BANK, MULTIBANK] {
        let asm = generate_ok(src, layout);
        let fwd = body(&asm, "FWD");
        assert!(fwd.contains("LDD >VAR_ARG0") && !fwd.contains("LDD #32"), "param replaced by the const:\n{fwd}");
        assert!(body(&asm, "LOOP_BODY").contains("LDD #32  ; const B"), "the const still folds outside");
    }
}

// ---------------------------------------------------------------------------
// Bug 9: one TMPVAL for every nested operand. `if a + 0 > b` parked b in
// TMPVAL, then `a + 0` overwrote it and the compare saw 0. The second-evaluated
// operand of a compare, a call argument, a min/max/clamp operand, a switch case
// or the value of `x op= v` could all overwrite a saved operand.
// ---------------------------------------------------------------------------

/// Lines of `asm` between the `; VPy_LINE:<line>` marker and the next one.
fn line_code(asm: &str, line: usize) -> String {
    let marker = format!("; VPy_LINE:{line}\n");
    let start = asm.find(&marker).unwrap_or_else(|| panic!("no code for line {line}")) + marker.len();
    let rest = &asm[start..];
    rest[..rest.find("; VPy_LINE:").unwrap_or(rest.len())].to_string()
}

/// Instructions only (no comments, no blank lines, no labels).
fn instrs(code: &str) -> Vec<String> {
    code.lines()
        .map(|l| l.split(';').next().unwrap().trim().to_string())
        .filter(|l| !l.is_empty() && !l.ends_with(':'))
        .collect()
}

const NESTED_SRC: &str = "\
a = 10
b = 5
c = 3
xs = [7, 8, 9]
k: u8 = 250
r = 0

def sub(p, q):
    return p - q

def swap_sub(p, q):
    return sub(q, p)

def main():
    SET_INTENSITY(127)

def loop():
    if a + 0 > b:
        r = 1
    r = sub(sub(a, b), sub(b, c))
    r = min(a + 1, sub(b, c) * 2)
    k += a * 2
    r = xs[a - 9] + xs[c - 1] * 2
    r = a.clamp(sub(b, c), a + 1)
";

fn assert_nested_operands_survive(asm: &str) {
    // line 18: compare whose LEFT is a binop → LEFT waits on the stack.
    assert_eq!(
        instrs(&line_code(asm, 18))[..8],
        ["LDD #0", "STD TMPVAL", "LDD >VAR_A", "ADDD TMPVAL", "PSHS D", "LDD >VAR_B", "STD TMPVAL", "PULS D"]
            .map(String::from),
        "a + 0 must be saved before b is evaluated"
    );
    assert!(instrs(&line_code(asm, 18)).contains(&"CMPD TMPVAL".to_string()));
    // line 20: nested user calls → arguments wait on the stack, then fill VAR_ARGn.
    let call = instrs(&line_code(asm, 20));
    let pos = |s: &str| call.iter().rposition(|l| l == s).unwrap_or_else(|| panic!("{s} missing: {call:?}"));
    assert!(pos("PSHS D") < pos("JSR SUB"), "first argument saved across the second call: {call:?}");
    // line 21: min() arguments are computed ahead into their slots.
    let m = instrs(&line_code(asm, 21));
    let hoisted = m.iter().position(|l| l == "STD >VAR___HOIST1").expect("second argument computed ahead");
    assert!(m[..hoisted].contains(&"PSHS D".to_string()) && m[hoisted + 1] == "PULS D", "{m:?}");
    // line 24: .clamp() operands live on the stack, dropped with one LEAS.
    let cl = instrs(&line_code(asm, 24));
    assert!(cl.contains(&"CMPD 2,S".to_string()) && cl.contains(&"LEAS 6,S".to_string()), "{cl:?}");
    // line 22: u8 compound assignment stores one byte.
    assert!(instrs(&line_code(asm, 22)).last().unwrap().starts_with("STB VAR_K"));
    // Every PSHS in the user code is matched by a PULS or a LEAS.
    let user = &asm[asm.find("LOOP_BODY:").unwrap()..asm.find("RUNTIME HELPERS").unwrap_or(asm.len())];
    let push = user.lines().filter(|l| l.trim_start().starts_with("PSHS D")).count();
    let pull = user.lines().filter(|l| l.trim_start().starts_with("PULS D")).count();
    let leas = user.matches("LEAS 4,S").count() * 2 + user.matches("LEAS 6,S").count() * 3;
    assert_eq!(push, pull + leas, "unbalanced stack in user code");
}

#[test]
fn nested_operands_survive_single_bank() {
    assert_nested_operands_survive(&generate_ok(NESTED_SRC, SINGLE_BANK));
}

#[test]
fn nested_operands_survive_multibank() {
    assert_nested_operands_survive(&generate_ok(NESTED_SRC, MULTIBANK));
}

#[test]
fn parameter_forwarded_in_another_position_is_not_overwritten() {
    // `sub(q, p)` inside swap_sub(p, q): storing VAR_ARG0 = q first used to
    // overwrite p before it was read.
    let asm = generate_ok(NESTED_SRC, SINGLE_BANK);
    let f = instrs(body(&asm, "SWAP_SUB"));
    assert_eq!(
        f[..6],
        ["LDD >VAR_ARG1", "PSHS D", "LDD >VAR_ARG0", "STD VAR_ARG1", "PULS D", "STD VAR_ARG0"].map(String::from),
        "{f:?}"
    );
}

#[test]
fn builtin_arguments_are_computed_ahead() {
    let src = "\
a = 10
b = 5

def f(v):
    return v + 1

def main():
    SET_INTENSITY(127)

def loop():
    DRAW_LINE(a + 1, f(b), a * 2, b - a, 127)
";
    let asm = generate_ok(src, SINGLE_BANK);
    assert!(asm.contains("VAR___HOIST3"), "four computed arguments need four slots");
    assert!(!asm.contains("VAR___HOIST4"), "the literal intensity needs none");
    let line = instrs(&line_code(&asm, 11));
    let first_builtin_read = line.iter().position(|l| l.starts_with("LDD >VAR___HOIST")).unwrap();
    assert!(line[..first_builtin_read].iter().filter(|l| *l == "PSHS D").count() == 3, "{line:?}");
    assert!(line[..first_builtin_read].iter().filter(|l| *l == "PULS D").count() == 3, "{line:?}");
}

#[test]
fn compound_assignment_with_computed_index_is_an_error() {
    let src = "\
xs = [1, 2]
i = 0

def main():
    xs[i + 1] += 2

def loop():
    pass
";
    let err = generate(src, SINGLE_BANK).expect_err("computed index in += must fail");
    assert!(err.contains("line 5") && err.contains("computed index"), "{err}");
}
