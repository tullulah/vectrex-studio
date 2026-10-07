//! End-to-end regressions for cross-module calls (`import physics` +
//! `physics.clamp_x(v)`), built with the real `vpy_cli`.
//!
//! - m6809: the call and the definition must use the same label (it used to be
//!   `JSR PHYSICS_clamp_x` against `PHYSICS_CLAMP_X:` → undefined symbol);
//!   single-bank and multibank cartridges.
//! - ARM (rp2350 / uvm2 / pitrex): the imported module's functions must be
//!   emitted at all (only the entry file used to be parsed).
//! - Errors: an import that does not resolve (a lone main.vpy) and a call to a
//!   function that does not exist fail with file/line, never a silent success.

use std::path::{Path, PathBuf};
use std::process::Command;

const PHYSICS: &str = "\
const MAX_X = 100
speed = 3
table = [1, 2, 3]

def clamp_x(v):
    if v > MAX_X:
        return MAX_X
    for i in range(0, 2):
        speed += table[i]
    return v + speed

def Step(v):
    speed = speed + 1
    return clamp_x(v) + table[1]
";

const MAIN: &str = "\
import physics

px = 0

def main():
    SET_INTENSITY(127)

def loop():
    WAIT_RECAL()
    px = physics.clamp_x(px)
    px = physics.CLAMP_X(px)
    px = physics.step(px)
    physics.speed = 2
    physics.table[1] = px
    px = px + physics.MAX_X + physics.table[0]
    DRAW_LINE(0, 0, px, 0, 127)
";

const MULTIBANK_META: &str = "META ROM_TOTAL_SIZE = 65536\nMETA ROM_BANK_SIZE = 16384\n\n";

/// Repository root: assembler/codegen find `ide/frontend/public/include/VECTREX.I` from here.
fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap()
}

fn project(main: &str) -> tempfile::TempDir {
    let tmp = tempfile::tempdir().unwrap();
    let dir = tmp.path();
    std::fs::create_dir_all(dir.join("src")).unwrap();
    std::fs::write(
        dir.join("xmod.vpyproj"),
        "[project]\nname = \"xmod\"\nversion = \"0.1.0\"\nentry = \"src/main.vpy\"\n\n[sources]\nvpy = [\"src/**/*.vpy\"]\n",
    )
    .unwrap();
    std::fs::write(dir.join("src/main.vpy"), main).unwrap();
    std::fs::write(dir.join("src/physics.vpy"), PHYSICS).unwrap();
    tmp
}

struct Run {
    ok: bool,
    output: String,
}

fn run(args: &[&str]) -> Run {
    let out = Command::new(env!("CARGO_BIN_EXE_vpy_cli"))
        .args(args)
        .current_dir(repo_root())
        .output()
        .expect("run vpy_cli");
    Run {
        ok: out.status.success(),
        output: format!("{}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr)),
    }
}

/// `vpy_cli build <input> --target m6809 -o <dir>/out.bin`; returns (run, generated asm).
fn build_m6809(input: &Path, out_dir: &Path) -> (Run, String) {
    let bin = out_dir.join("out.bin");
    let r = run(&["build", input.to_str().unwrap(), "--target", "m6809", "-o", bin.to_str().unwrap()]);
    let asm = std::fs::read_to_string(bin.with_extension("asm")).unwrap_or_default();
    (r, asm)
}

/// `vpy_cli asm <input> --target <t> -o <file>` (codegen only, no toolchain needed).
fn asm_for(input: &Path, target: &str, out_dir: &Path) -> (Run, String) {
    let out = out_dir.join(format!("out_{target}.s"));
    let r = run(&["asm", input.to_str().unwrap(), "--target", target, "-o", out.to_str().unwrap()]);
    (r, std::fs::read_to_string(&out).unwrap_or_default())
}

fn assert_has_line(asm: &str, line: &str) {
    assert!(
        asm.lines().any(|l| l.trim() == line),
        "expected `{line}` in the generated assembly"
    );
}

#[test]
fn m6809_single_bank_module_calls_link() {
    let p = project(MAIN);
    let (r, asm) = build_m6809(&p.path().join("xmod.vpyproj"), p.path());
    assert!(r.ok, "build failed:\n{}", r.output);
    // definition and every call (any spelling) agree on one label
    assert_has_line(&asm, "PHYSICS_CLAMP_X:");
    assert_has_line(&asm, "PHYSICS_STEP:");
    assert_eq!(asm.lines().filter(|l| l.trim() == "JSR PHYSICS_CLAMP_X").count(), 3, "2 from main + 1 from Step");
    assert_has_line(&asm, "JSR PHYSICS_STEP");
    // module globals/consts/arrays, read and written from both modules
    assert!(asm.contains("STD VAR_PHYSICS_SPEED"));
    assert!(asm.contains("VAR_PHYSICS_TABLE_DATA"));
    assert!(!asm.contains("VAR_SPEED") && !asm.contains("VAR_TABLE") && !asm.contains("JSR CLAMP_X"),
        "a module symbol was referenced without its prefix");
}

#[test]
fn m6809_multibank_module_calls_link() {
    let p = project(&format!("{MULTIBANK_META}{MAIN}"));
    let (r, _) = build_m6809(&p.path().join("xmod.vpyproj"), p.path());
    assert!(r.ok, "multibank build failed:\n{}", r.output);
    assert!(r.output.to_lowercase().contains("multibank"), "expected a multibank build:\n{}", r.output);
}

#[test]
fn arm_targets_emit_imported_module_functions() {
    let p = project(MAIN);
    let proj = p.path().join("xmod.vpyproj");
    for target in ["rp2350", "uvm2", "pitrex"] {
        let (r, asm) = asm_for(&proj, target, p.path());
        assert!(r.ok, "{target} codegen failed:\n{}", r.output);
        assert_has_line(&asm, "PHYSICS_clamp_x:");
        assert_has_line(&asm, "PHYSICS_Step:");
        assert!(asm.lines().any(|l| l.split_whitespace().collect::<Vec<_>>() == ["bl", "PHYSICS_clamp_x"]),
            "{target}: no `bl PHYSICS_clamp_x`");
        assert!(asm.contains("VAR_PHYSICS_SPEED"), "{target}: module global not allocated");
    }
}

#[test]
fn lone_main_with_import_is_a_compile_error() {
    let p = project(MAIN);
    let main = p.path().join("src/main.vpy");
    for target in ["m6809", "rp2350"] {
        let bin = p.path().join(format!("lone_{target}.bin"));
        let r = run(&["build", main.to_str().unwrap(), "--target", target, "-o", bin.to_str().unwrap()]);
        assert!(!r.ok, "{target}: a lone main.vpy importing a missing module must fail:\n{}", r.output);
        let want = format!("{}:1: error: module `physics` not found", main.display());
        assert!(r.output.contains(&want), "{target}: missing `{want}` in:\n{}", r.output);
        assert!(r.output.contains(".vpyproj"), "{target}: the error should point at the project build");
        assert!(!bin.exists(), "{target}: no ROM may be written");
    }
}

#[test]
fn unknown_module_member_is_a_compile_error() {
    let p = project(&MAIN.replace("physics.step(px)", "physics.stepp(px)"));
    let (r, _) = build_m6809(&p.path().join("xmod.vpyproj"), p.path());
    assert!(!r.ok);
    assert!(r.output.contains("main.vpy:12: error: module `physics` has no function, variable or const named `stepp`"),
        "{}", r.output);
}

#[test]
fn unknown_function_is_a_compile_error_with_line() {
    let p = project(&MAIN.replace("    DRAW_LINE(0, 0, px, 0, 127)\n", "    DRAW_LINE(0, 0, px, 0, 127)\n    draw_lien(1)\n"));
    let proj = p.path().join("xmod.vpyproj");
    let (r, _) = build_m6809(&proj, p.path());
    assert!(!r.ok, "m6809 must fail:\n{}", r.output);
    assert!(r.output.contains("line 17: `DRAW_LIEN()` is not a builtin"), "{}", r.output);
    for target in ["rp2350", "pitrex"] {
        let (r, _) = asm_for(&proj, target, p.path());
        assert!(!r.ok, "{target} must fail:\n{}", r.output);
        assert!(r.output.contains("line 17: `DRAW_LIEN()` is not a builtin"), "{target}: {}", r.output);
    }
}
