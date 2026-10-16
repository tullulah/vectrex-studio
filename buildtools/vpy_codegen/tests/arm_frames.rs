//! Call frames on the ARM targets (rp2350, uvm2: Thumb-2; pitrex: ARM32).
//!
//! Parameters and locals used to live in one global RAM slot per NAME, shared by
//! every function: `def f(a): t = g(5); return a + t` read g's `a`, two functions
//! with a `t` or a `for i` overwrote each other, and recursion that read a
//! parameter after the recursive call (`fib`) returned garbage. Every user
//! function now gets a stack frame (AAPCS: `push {…, r7, lr}`, `sub sp`, r7 =
//! frame pointer); parameters and locals are r7-relative slots of that frame, and
//! globals keep their fixed addresses. The m6809 counterpart (static frames,
//! overlaid by call graph) is in `src/m6809/regression_tests.rs`.

use vpy_codegen::{BankConfig, Target};

const FRAMES_SRC: &str = "\
x = 7
r = 0

def g(a):
    return a + 1

def f(a):
    t = g(5)
    return a + t

def inner(k):
    total = 0
    for i in range(0, k):
        total = total + 1
    return total

def outer():
    total = 0
    for i in range(0, 3):
        total = total + inner(4)
    return total

def shadow(x):
    return x * 2

def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

def pick(v):
    switch v:
        case 1:
            return 10
        default:
            return 20
    return 0

def five(a, b, c, d, e):
    return a + b + c + d + e

def main():
    SET_INTENSITY(127)

def loop():
    r = f(100) + outer() + shadow(21) + fib(6) + pick(1)
    r = f(g(1) + 1) + five(1, 2, 3, 4, x)
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

/// The code of function `label`: from its label to the end of its literal pool.
fn body<'a>(asm: &'a str, label: &str) -> &'a str {
    let start = asm.find(&format!("\n{label}:\n")).unwrap_or_else(|| panic!("no function {label}"));
    let rest = &asm[start + 1..];
    &rest[..rest.find("\n    .ltorg").unwrap_or(rest.len())]
}

/// Instructions of `code`, comments stripped, whitespace collapsed.
fn instrs(code: &str) -> Vec<String> {
    code.lines()
        .map(|l| l.split('@').next().unwrap().split_whitespace().collect::<Vec<_>>().join(" "))
        .filter(|l| !l.is_empty())
        .collect()
}

/// Bytes the function's prologue pushes (`push {r4, …, lr}`).
fn pushed_bytes(code: &[String]) -> usize {
    let push = code.iter().find(|l| l.starts_with("push {r4")).expect("prologue push");
    4 * push.matches('r').count() // r4 … plus the r of `lr`
}

/// Value of a `.equ NAME, VALUE` line.
fn equ<'a>(asm: &'a str, name: &str) -> Option<&'a str> {
    asm.lines().find_map(|l| {
        let rest = l.trim().strip_prefix(".equ")?.trim_start();
        let (n, v) = rest.split_once(',')?;
        (n.trim() == name).then(|| v.split_whitespace().next().unwrap_or(""))
    })
}

fn assert_stack_frames(asm: &str, target: &Target) {
    // Parameters and locals have no global slot; globals keep theirs.
    for name in ["A", "T", "K", "TOTAL", "I", "N", "V", "B", "E"] {
        assert!(equ(asm, &format!("VAR_{name}")).is_none(), "{target:?}: `{name}` still has a global slot");
    }
    let x_addr = equ(asm, "VAR_X").unwrap_or_else(|| panic!("{target:?}: global x lost its slot"));
    assert!(equ(asm, "VAR_R").is_some(), "{target:?}");

    // f: frame set up, `a` saved into it, and read back from it AFTER calling g.
    let f = instrs(body(asm, "F"));
    let sub = f.iter().find_map(|l| l.strip_prefix("sub sp, sp, #")).expect("frame allocation");
    let frame: usize = sub.parse().unwrap();
    assert_eq!((pushed_bytes(&f) + frame) % 8, 0, "{target:?}: sp not 8-byte aligned inside f: {f:?}");
    assert!(f.contains(&"mov r7, sp".to_string()), "{target:?}: no frame pointer: {f:?}");
    assert!(f.contains(&"str r0, [r7, #0]".to_string()), "{target:?}: `a` not saved in f's frame: {f:?}");
    let call = f.iter().position(|l| l == "bl G").expect("f calls g");
    assert!(
        f[call..].iter().any(|l| l.ends_with("[r7, #0]") && l.starts_with("ldr")),
        "{target:?}: f must read its own `a` from its frame after the call: {f:?}"
    );
    // One epilogue per function: every return restores sp from the frame pointer.
    let pops = f.iter().filter(|l| l.starts_with("pop {r4") && l.ends_with("pc}")).count();
    assert_eq!(pops, 1, "{target:?}: {f:?}");
    let pop = f.iter().position(|l| l.starts_with("pop {r4")).unwrap();
    assert_eq!(f[pop - 2], "mov sp, r7", "{target:?}: {f:?}");

    // Same local names in caller and callee: each in its own frame.
    for func in ["INNER", "OUTER"] {
        let code = body(asm, func);
        assert!(code.contains("[r7, #"), "{target:?}: {func} locals not in its frame");
    }

    // A parameter named like a global is the parameter; the global is untouched.
    let shadow = body(asm, "SHADOW");
    assert!(!shadow.contains(x_addr) && !shadow.contains("VAR_X"), "{target:?}: shadow writes the global x");

    // Recursion: n is read from the current activation after the first recursive call.
    let fib = instrs(body(asm, "FIB"));
    let first = fib.iter().position(|l| l == "bl FIB").expect("fib recursion");
    assert!(fib[first + 1..].iter().any(|l| l.starts_with("ldr") && l.contains("[r7, #")), "{target:?}: {fib:?}");

    // A return inside a switch (which keeps its value on the stack) leaves through the epilogue.
    let pick = instrs(body(asm, "PICK"));
    let pops = pick.iter().filter(|l| l.starts_with("pop {r4")).count();
    assert_eq!(pops, 1, "{target:?}: return inside switch must restore sp: {pick:?}");

    // Fifth argument: read from the caller's stack above the saved registers and the frame.
    let five = instrs(body(asm, "FIVE"));
    let sub: usize = five.iter().find_map(|l| l.strip_prefix("sub sp, sp, #")).unwrap().parse().unwrap();
    let stack_arg = format!("ldr r0, [r7, #{}]", sub + pushed_bytes(&five));
    assert!(five.contains(&stack_arg), "{target:?}: expected `{stack_arg}`: {five:?}");
}

#[test]
fn parameters_and_locals_live_in_stack_frames() {
    for target in ARM_TARGETS {
        let asm = generate(FRAMES_SRC, &target).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        assert_stack_frames(&asm, &target);
    }
}

#[test]
fn main_and_loop_locals_live_in_the_game_main_frame() {
    let src = "\
r = 0

def main():
    t = 3
    r = t

def loop():
    u = r + 1
    r = u
";
    for target in ARM_TARGETS {
        let asm = generate(src, &target).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        assert!(equ(&asm, "VAR_T").is_none() && equ(&asm, "VAR_U").is_none(), "{target:?}");
        // The entry point (pitrex: `main`) up to the jump back to the top of its game loop.
        let (entry, back) = match target {
            Target::PiTrex => ("main", "b       pitrex_game_loop\n"),
            _ => ("game_main", "b       game_main_loop\n"),
        };
        let start = asm.find(&format!("\n{entry}:\n")).unwrap();
        let end = start + asm[start..].find(back).unwrap();
        let gm = instrs(&asm[start..end]);
        assert!(gm.contains(&"mov r7, sp".to_string()), "{target:?}: {gm:?}");
        let sub: usize = gm.iter().find_map(|l| l.strip_prefix("sub sp, sp, #")).unwrap().parse().unwrap();
        assert_eq!((pushed_bytes(&gm) + sub) % 8, 0, "{target:?}: {gm:?}");
        // main's t and loop's u are two different slots.
        assert!(gm.contains(&"str r0, [r7, #0]".to_string()), "{target:?}: {gm:?}");
        assert!(gm.contains(&"str r0, [r7, #4]".to_string()), "{target:?}: {gm:?}");
    }
}

#[test]
fn undeclared_name_and_wrong_argument_count_are_errors() {
    // A local of main() is not visible in loop() (it used to be one shared global).
    let undeclared = "\
r = 0

def main():
    t = 3

def loop():
    r = t
";
    let arity = "r = 0\n\ndef two(a, b):\n    return a + b\n\ndef main():\n    pass\n\ndef loop():\n    r = two(1)\n";
    for target in ARM_TARGETS {
        let e = generate(undeclared, &target).expect_err("must fail");
        assert!(e.contains("line 7: `t` is used in `loop()`") && e.contains("declare it at top level"), "{target:?}: {e}");
        let e = generate(arity, &target).expect_err("must fail");
        assert!(e.contains("line 10: `two()` takes 2 arguments but is called with 1"), "{target:?}: {e}");
    }
}
