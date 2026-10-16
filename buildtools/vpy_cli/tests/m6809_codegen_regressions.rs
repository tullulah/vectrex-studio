//! End-to-end regressions for m6809 codegen bugs that only failed at assembly
//! time. Each program is built with the real `vpy_cli build --target m6809`
//! (parse → unify → codegen → assemble → link → .bin) as a single-bank and as a
//! multibank cartridge; error cases check the compile error text.

use std::path::Path;
use std::process::Command;

const MULTIBANK_META: &str = "META ROM_TOTAL_SIZE = 65536\nMETA ROM_BANK_SIZE = 16384\n\n";

struct Build {
    ok: bool,
    output: String,
    asm: Option<String>,
}

fn build(dir: &Path, name: &str, src: &str) -> Build {
    let source = dir.join(format!("{name}.vpy"));
    std::fs::write(&source, src).expect("write source");
    let bin = dir.join(format!("{name}.bin"));
    let out = Command::new(env!("CARGO_BIN_EXE_vpy_cli"))
        .arg("build")
        .arg(&source)
        .args(["--target", "m6809", "-o"])
        .arg(&bin)
        .current_dir(dir)
        .output()
        .expect("run vpy_cli");
    let output = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    let asm = std::fs::read_to_string(bin.with_extension("asm")).ok();
    Build { ok: out.status.success() && bin.exists(), output, asm }
}

fn tmp() -> tempfile::TempDir {
    tempfile::tempdir().expect("tempdir")
}

/// Build `src` as single-bank and as multibank; both must produce a ROM.
fn assert_builds_both_layouts(name: &str, src: &str) -> (Build, Build) {
    let dir = tmp();
    let single = build(dir.path(), name, src);
    assert!(single.ok, "single-bank build of {name} failed:\n{}", single.output);
    let multi_src = format!("{MULTIBANK_META}{src}");
    let multi = build(dir.path(), &format!("{name}_mb"), &multi_src);
    assert!(multi.ok, "multibank build of {name} failed:\n{}", multi.output);
    assert!(
        multi.output.to_lowercase().contains("multibank"),
        "expected a multibank build for {name}:\n{}",
        multi.output
    );
    (single, multi)
}

fn assert_label(build: &Build, label: &str) {
    let asm = build.asm.as_deref().expect("generated .asm next to the .bin");
    let want = format!("{label}:");
    assert!(
        asm.lines().any(|l| l.trim_end() == want || l.starts_with(&format!("{want} "))),
        "label {label} not defined in generated assembly"
    );
}

/// Does `output` point at source line `n` ("file.vpy:N: error:", or "line N")?
fn names_line(output: &str, n: usize) -> bool {
    output.contains(&format!(".vpy:{n}: error:")) || output.contains(&format!("line {n}"))
}

fn assert_fails_with(name: &str, src: &str, needles: &[&str]) {
    let dir = tmp();
    let b = build(dir.path(), name, src);
    assert!(!b.ok, "{name} should fail to build:\n{}", b.output);
    let lower = b.output.to_lowercase();
    for needle in needles {
        let found = match needle.strip_prefix("line ").and_then(|n| n.parse::<usize>().ok()) {
            Some(n) => names_line(&b.output, n),
            None => lower.contains(&needle.to_lowercase()),
        };
        assert!(found, "missing '{needle}' in error output:\n{}", b.output);
    }
}

#[test]
fn builtins_only_inside_for_body() {
    let src = "\
def main():
    SET_INTENSITY(127)

def loop():
    for i in range(0, 3):
        DRAW_LINE(i, 0, 10, 10, 127)
        DRAW_CIRCLE(i, 0, 10)
";
    let (single, multi) = assert_builds_both_layouts("for_body", src);
    for b in [&single, &multi] {
        assert_label(b, "DRAW_LINE_WRAPPER");
        assert_label(b, "DRAW_CIRCLE_RUNTIME");
    }
}

#[test]
fn joystick_reads_only_in_conditions() {
    let src = "\
def main():
    SET_INTENSITY(127)

def loop():
    if J1_X() > 20:
        PRINT_TEXT(0, 0, \"R\")
    if J1_Y() < -20:
        PRINT_TEXT(0, 0, \"D\")
    if J2_X() > 20 and J2_Y() > 0:
        PRINT_TEXT(0, 0, \"X\")
";
    let (single, multi) = assert_builds_both_layouts("joy_cond", src);
    for b in [&single, &multi] {
        for label in ["J1X_BUILTIN", "J1Y_BUILTIN", "J2X_BUILTIN", "J2Y_BUILTIN"] {
            assert_label(b, label);
        }
    }
}

#[test]
fn unused_global_arrays() {
    let src = "\
xs = [1, 2, 3]
bs: u8 = [4, 5, 6]
const YS = [7, 8]

def main():
    SET_INTENSITY(127)

def loop():
    PRINT_TEXT(0, 0, \"HI\")
";
    assert_builds_both_layouts("unused_array", src);
}

#[test]
fn arrays_iterated_and_measured() {
    let src = "\
xs = [1, 2, 3]
const YS = [4, 5, 6, 7]
total = 0

def main():
    SET_INTENSITY(127)

def loop():
    total = len(xs) + len(YS)
    for v in YS:
        total = total + v
    for v in xs:
        total = total + v
    PRINT_NUMBER(0, 0, total)
";
    assert_builds_both_layouts("array_len", src);
}

#[test]
fn len_of_non_array_is_a_compile_error() {
    assert_fails_with(
        "len_scalar",
        "score = 3\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    PRINT_NUMBER(0, 0, len(score))\n",
        &["len(score)", "not a global array"],
    );
}

#[test]
fn len_of_parameter_is_a_compile_error() {
    let src = format!(
        "{MULTIBANK_META}def count(a):\n    return len(a)\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    pass\n"
    );
    assert_fails_with("len_param", &src, &["len(a)", "parameter"]);
}

#[test]
fn rebinding_a_global_array_is_a_compile_error() {
    assert_fails_with(
        "array_rebind",
        "xs = [1, 2, 3]\n\ndef main():\n    xs = 5\n\ndef loop():\n    pass\n",
        &["cannot assign to global array 'xs'"],
    );
}

#[test]
fn typed_arrays_for_in_and_array_parameters_link() {
    let src = "\
words = [10, 20, 30]
bytes: u8 = [1, 2, 200]
signed: i8 = [-1, 5]
const A = 3
const B = A * 2 + 1
total = 0

def sum_words(arr):
    return arr[0] + arr[2]

def first_byte(bs):
    bs[1] = B
    return bs[0]

def main():
    SET_INTENSITY(127)
    wait(20)
    wait(B * 5)

def loop():
    total = sum_words(words) + first_byte(bytes)
    for v in bytes:
        total = total + v
    for s in signed:
        total = total + s
    PRINT_NUMBER(0, 0, total)
";
    let (single, multi) = assert_builds_both_layouts("arrays_consts_waits", src);
    for b in [&single, &multi] {
        assert_label(b, "SUM_WORDS");
        assert_label(b, "FIRST_BYTE");
        let asm = b.asm.as_deref().unwrap();
        assert!(!asm.contains("ARRAY_ARR_DATA") && !asm.contains("ARRAY_BS_DATA"));
        assert!(asm.contains("LDD #7  ; const B"), "const B folds to 7");
    }
}

#[test]
fn array_and_const_errors_fail_with_line() {
    assert_fails_with(
        "bad_const",
        "speed = 2\nconst B = speed * 2\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    PRINT_NUMBER(0, 0, B)\n",
        &["line 2", "const `B` cannot be computed at compile time"],
    );
    assert_fails_with(
        "bad_index",
        "n = 3\n\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    PRINT_NUMBER(0, 0, n[1])\n",
        &["line 7", "`N` is not an array"],
    );
    assert_fails_with(
        "bad_sample",
        "def main():\n    SET_INTENSITY(127)\n\ndef loop():\n    PLAY_SAMPLE(\"voice\")\n",
        &["line 5", "PLAY_SAMPLE is not supported on m6809"],
    );
}

/// Parameters and locals live in per-function static frames (overlaid by call
/// graph); a function that calls another still reads its own parameter.
#[test]
fn static_frames_link_in_both_layouts() {
    let src = "\
r = 0

def g(x):
    return x + 1

def f(a):
    t = g(5)
    return a + t

def main():
    SET_INTENSITY(127)

def loop():
    r = f(100)
    PRINT_NUMBER(0, 0, r)
";
    let (single, multi) = assert_builds_both_layouts("static_frames", src);
    for b in [&single, &multi] {
        let asm = b.asm.as_deref().unwrap();
        assert!(asm.contains("STD >VAR_G__X") && asm.contains("LDD >VAR_F__A"), "frame slots");
        assert!(asm.contains("FRAME_POOL"), "frame pool allocated");
    }
}

/// A call between switchable banks goes through a trampoline in the helpers bank;
/// it must hand back the callee's return value (D) intact: restoring the caller's
/// bank used to overwrite A, the high byte.
#[test]
fn cross_bank_call_keeps_the_return_value() {
    let mut src = String::from(MULTIBANK_META);
    src.push_str("junk = 0\nr = 0\n");
    for k in 0..5 {
        src.push_str(&format!("\ndef filler{k}(q):\n"));
        for i in 0..300 {
            src.push_str(&format!("    junk = junk + q + {i}\n"));
        }
        src.push_str("    return q * 1000\n");
    }
    src.push_str("\ndef main():\n    SET_INTENSITY(127)\n\ndef loop():\n    r = filler4(2) + filler3(1)\n");
    let dir = tmp();
    let b = build(dir.path(), "cross_bank", &src);
    assert!(b.ok, "multibank build failed:\n{}", b.output);
    let mut trampolines = String::new();
    for entry in std::fs::read_dir(dir.path().join("multibank_temp")).expect("multibank_temp") {
        let text = std::fs::read_to_string(entry.unwrap().path()).unwrap_or_default();
        if let Some(at) = text.find("TRAMP_") {
            trampolines.push_str(&text[at..]);
        }
    }
    assert!(trampolines.contains("JSR TRAMP_FILLER") || trampolines.contains("TRAMP_FILLER"),
        "expected a cross-bank call (functions spread over banks):\n{}", b.output);
    assert!(!trampolines.contains("    PULS A\n"), "trampoline overwrites the return value's high byte");
    assert!(trampolines.contains("PSHS D,CC") && trampolines.contains("PULS CC,D"), "{trampolines}");
}

#[test]
fn recursion_and_undeclared_names_fail_with_line() {
    assert_fails_with(
        "recursive",
        "r = 0\n\ndef fact(n):\n    if n < 2:\n        return 1\n    return n * fact(n - 1)\n\ndef main():\n    pass\n\ndef loop():\n    r = fact(5)\n",
        &["recursion is not supported on m6809", "`fact()` calls `fact()` at line 6"],
    );
    assert_fails_with(
        "undeclared",
        "r = 0\n\ndef main():\n    t = 3\n\ndef loop():\n    r = t\n",
        &["line 7", "`t` is used in `loop()`"],
    );
}

// ---------------------------------------------------------------------------
// DRAW_VECTOR_ROT: assembles and links with the sprite's own path table, in a
// single-bank and in a multibank cartridge (bank-switching wrapper).
// ---------------------------------------------------------------------------

const ELL_VEC: &str = r#"{"version":"1.0","name":"ell","canvas":{"width":256,"height":256,"origin":"center"},
 "layers":[{"name":"default","visible":true,"paths":[
  {"name":"l","intensity":100,"closed":false,"points":[{"x":-20,"y":-10},{"x":20,"y":-10},{"x":20,"y":10}]}]}]}"#;

fn dir_with_ell() -> tempfile::TempDir {
    let dir = tmp();
    std::fs::create_dir_all(dir.path().join("assets/vectors")).unwrap();
    std::fs::write(dir.path().join("assets/vectors/ell.vec"), ELL_VEC).unwrap();
    dir
}

#[test]
fn draw_vector_rot_builds_single_and_multibank() {
    let src = "\
angle = 0

def main():
    SET_INTENSITY(127)

def loop():
    DRAW_VECTOR_ROT(\"ell\", 30, 20, angle)
    DRAW_VECTOR_ROT(\"ell\", -40, -30, angle, 1, 50)
    angle = angle + 32
";
    let dir = dir_with_ell();
    let single = build(dir.path(), "rot", src);
    assert!(single.ok, "single-bank build failed:\n{}", single.output);
    assert_label(&single, "DRAW_VEC_ROT_RUNTIME");
    let multi = build(dir.path(), "rot_mb", &format!("{MULTIBANK_META}{src}"));
    assert!(multi.ok, "multibank build failed:\n{}", multi.output);
    assert_label(&multi, "DRAW_VEC_ROT_BANKED");
    assert_label(&multi, "DRAW_VEC_ROT_RUNTIME");
}

#[test]
fn draw_vector_rot_errors_name_the_line() {
    let dir = dir_with_ell();
    let unknown = build(dir.path(), "rot_unknown",
        "def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR_ROT(\"ship\", 0, 0, 8)\n");
    assert!(!unknown.ok && names_line(&unknown.output, 5) && unknown.output.contains("no vector asset named 'ship'"),
        "{}", unknown.output);
    let arity = build(dir.path(), "rot_arity",
        "def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR_ROT(\"ell\", 0, 0)\n");
    assert!(!arity.ok && arity.output.contains("takes 4 to 6 arguments"), "{}", arity.output);
}
