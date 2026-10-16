//! End-to-end: a parameter or local of an imported module's function never
//! uses the storage of the main program's global of the same name (it used to:
//! `x = 0` inside `enemies.reset()` wrote main's `x`, a `for i` loop counted
//! with main's `i`, and on ARM the parameter `x` was saved into main's `x`).
//! Built with the real `vpy_cli` (m6809 single-bank + multibank, ARM codegen),
//! plus the error case: a module reading the main program's global.

use std::path::{Path, PathBuf};
use std::process::Command;

const MAIN: &str = "\
import enemies

x = 5
i = 7

def main():
    SET_INTENSITY(127)

def loop():
    y = enemies.update(3)
    z = enemies.reset()
    w = enemies.count()
    PRINT_NUMBER(x, i, y + z + w)
";

const ENEMIES: &str = "\
def update(x):
    return x + 1

def reset():
    x = 0
    return x

def count():
    total = 0
    for i in range(0, 3):
        total = total + i
    return total
";

const MULTIBANK_META: &str = "META ROM_TOTAL_SIZE = 65536\nMETA ROM_BANK_SIZE = 16384\n\n";

fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..").canonicalize().unwrap()
}

fn project(main: &str, enemies: &str) -> tempfile::TempDir {
    let tmp = tempfile::tempdir().unwrap();
    let dir = tmp.path();
    std::fs::create_dir_all(dir.join("src")).unwrap();
    std::fs::write(
        dir.join("scope.vpyproj"),
        "[project]\nname = \"scope\"\nversion = \"0.1.0\"\nentry = \"src/main.vpy\"\n\n[sources]\nvpy = [\"src/**/*.vpy\"]\n",
    )
    .unwrap();
    std::fs::write(dir.join("src/main.vpy"), main).unwrap();
    std::fs::write(dir.join("src/enemies.vpy"), enemies).unwrap();
    tmp
}

fn run(args: &[&str]) -> (bool, String) {
    let out = Command::new(env!("CARGO_BIN_EXE_vpy_cli"))
        .args(args)
        .current_dir(repo_root())
        .output()
        .expect("run vpy_cli");
    (
        out.status.success(),
        format!("{}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr)),
    )
}

fn build_m6809(dir: &Path) -> (bool, String, String) {
    let bin = dir.join("out.bin");
    let proj = dir.join("scope.vpyproj");
    let (ok, output) = run(&["build", proj.to_str().unwrap(), "--target", "m6809", "-o", bin.to_str().unwrap()]);
    let asm = std::fs::read_to_string(bin.with_extension("asm")).unwrap_or_default();
    (ok && bin.exists(), output, asm)
}

/// The instructions of function `label` (from `label:` to its first RTS).
fn m6809_function<'a>(asm: &'a str, label: &str) -> &'a str {
    let start = asm.find(&format!("\n{label}:")).unwrap_or_else(|| panic!("{label} not defined"));
    let body = &asm[start..];
    &body[..body.find("RTS").unwrap_or(body.len())]
}

/// True if an instruction operand names `symbol` exactly (`VAR_X`, `>VAR_X`).
fn names_symbol(code: &str, symbol: &str) -> bool {
    code.split(|c: char| c.is_whitespace() || c == ',' || c == '>' || c == '#').any(|t| t == symbol)
}

fn assert_locals_have_their_own_storage(asm: &str) {
    for f in ["ENEMIES_UPDATE", "ENEMIES_RESET", "ENEMIES_COUNT"] {
        let code = m6809_function(asm, f);
        for global in ["VAR_X", "VAR_I"] {
            assert!(!names_symbol(code, global), "{f} uses main's global {global}:\n{code}");
        }
    }
    assert!(names_symbol(m6809_function(asm, "ENEMIES_RESET"), "VAR_ENEMIES_RESET__X__L"));
    assert!(names_symbol(m6809_function(asm, "ENEMIES_UPDATE"), "VAR_ENEMIES_UPDATE__X__L"));
    assert!(names_symbol(m6809_function(asm, "ENEMIES_COUNT"), "VAR_ENEMIES_COUNT__I__L"));
    // main's loop() still reads its own globals
    let lp = m6809_function(asm, "LOOP_BODY");
    assert!(names_symbol(lp, "VAR_X") && names_symbol(lp, "VAR_I"), "{lp}");
}

#[test]
fn m6809_single_bank_module_locals_are_not_main_globals() {
    let p = project(MAIN, ENEMIES);
    let (ok, output, asm) = build_m6809(p.path());
    assert!(ok, "build failed:\n{output}");
    assert_locals_have_their_own_storage(&asm);
}

#[test]
fn m6809_multibank_module_locals_are_not_main_globals() {
    let p = project(&format!("{MULTIBANK_META}{MAIN}"), ENEMIES);
    let (ok, output, asm) = build_m6809(p.path());
    assert!(ok, "multibank build failed:\n{output}");
    assert!(output.to_lowercase().contains("multibank"), "expected a multibank build:\n{output}");
    assert_locals_have_their_own_storage(&asm);
}

#[test]
fn arm_module_parameter_does_not_overwrite_main_global() {
    let p = project(MAIN, ENEMIES);
    let proj = p.path().join("scope.vpyproj");
    let out = p.path().join("out.s");
    let (ok, output) = run(&["asm", proj.to_str().unwrap(), "--target", "rp2350", "-o", out.to_str().unwrap()]);
    assert!(ok, "rp2350 codegen failed:\n{output}");
    let asm = std::fs::read_to_string(&out).unwrap();
    // the parameter / locals named like main's globals live in each function's
    // stack frame (r7-relative, arm/frame.rs); main's x and i keep their addresses
    let equ = |name: &str| {
        asm.lines()
            .find_map(|l| l.strip_prefix(&format!(".equ {name}, ")).map(|v| v.split_whitespace().next().unwrap().to_string()))
            .unwrap_or_else(|| panic!("{name} not declared:\n{asm}"))
    };
    let (x, i) = (equ("VAR_X"), equ("VAR_I"));
    for f in ["ENEMIES_update", "ENEMIES_reset", "ENEMIES_count"] {
        let start = asm.find(&format!("\n{f}:\n")).unwrap_or_else(|| panic!("{f} not defined:\n{asm}"));
        let code = &asm[start..start + asm[start..].find(".ltorg").unwrap()];
        assert!(!code.contains(&x) && !code.contains(&i), "{f} uses main's globals:\n{code}");
        assert!(code.contains("[r7, #"), "{f} has no frame slot:\n{code}");
    }
}

#[test]
fn module_reading_main_global_is_a_compile_error() {
    let p = project(MAIN, &ENEMIES.replace("    x = 0\n    return x\n", "    return x\n"));
    let (ok, output, _) = build_m6809(p.path());
    assert!(!ok, "a module reading main's global must not build:\n{output}");
    assert!(output.contains("enemies.vpy:5: error: `x` is not defined in module `enemies`"), "{output}");
    assert!(output.contains("global of the main program"), "{output}");
}
