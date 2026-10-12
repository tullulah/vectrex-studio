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
    assert!(r.output.contains("main.vpy:12: error: module `physics` has no function, variable, const or struct named `stepp`"),
        "{}", r.output);
}

#[test]
fn unknown_function_is_a_compile_error_with_line() {
    let p = project(&MAIN.replace("    DRAW_LINE(0, 0, px, 0, 127)\n", "    DRAW_LINE(0, 0, px, 0, 127)\n    draw_lien(1)\n"));
    let proj = p.path().join("xmod.vpyproj");
    let (r, _) = build_m6809(&proj, p.path());
    assert!(!r.ok, "m6809 must fail:\n{}", r.output);
    // The error names the file of the function it is in.
    assert!(r.output.contains("main.vpy:17: error: `DRAW_LIEN()` is not a builtin"), "{}", r.output);
    for target in ["rp2350", "pitrex"] {
        let (r, _) = asm_for(&proj, target, p.path());
        assert!(!r.ok, "{target} must fail:\n{}", r.output);
        assert!(r.output.contains("main.vpy:17: error: `DRAW_LIEN()` is not a builtin"), "{target}: {}", r.output);
    }
}

/// Every VPy line in the .pdb, as (file, line) pairs, from `vpyLineMap`.
fn pdb_lines(pdb: &serde_json::Value) -> Vec<(String, u64)> {
    let mut v: Vec<(String, u64)> = pdb["vpyLineMap"]
        .as_object()
        .expect("vpyLineMap")
        .values()
        .map(|e| (e["file"].as_str().unwrap().to_string(), e["line"].as_u64().unwrap()))
        .collect();
    v.sort();
    v.dedup();
    v
}

fn assert_pdb_attributes_imported_lines(pdb_path: &Path) {
    let pdb: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(pdb_path).expect("pdb written")).unwrap();
    let lines = pdb_lines(&pdb);
    // physics.vpy line 7 (`return MAX_X` in clamp_x) maps to physics.vpy; main.vpy
    // has no code on line 7. Line 6 has code in both files and both are kept.
    assert!(lines.contains(&("physics.vpy".to_string(), 7)), "imported line not attributed to physics.vpy: {lines:?}");
    assert!(lines.contains(&("main.vpy".to_string(), 11)), "entry line missing: {lines:?}");
    assert!(!lines.contains(&("main.vpy".to_string(), 7)), "physics.vpy line 7 attributed to main.vpy: {lines:?}");
    assert!(lines.contains(&("main.vpy".to_string(), 6)) && lines.contains(&("physics.vpy".to_string(), 6)));
    assert_eq!(pdb["lineMap"]["6"], pdb["fileLineMap"]["main.vpy"]["6"]);
    assert_ne!(pdb["fileLineMap"]["main.vpy"]["6"], pdb["fileLineMap"]["physics.vpy"]["6"]);
    assert_eq!(pdb["functions"]["PHYSICS_CLAMP_X"]["file"], "physics.vpy");
    assert_eq!(pdb["functions"]["LOOP"]["file"], "main.vpy");
    // Per-file breakpoints; lineMap (line numbers only) keeps the entry file's.
    assert!(pdb["fileLineMap"]["physics.vpy"]["7"].is_string());
    assert_eq!(pdb["lineMap"].as_object().unwrap(), pdb["fileLineMap"]["main.vpy"].as_object().unwrap());
}

#[test]
fn pdb_points_imported_code_at_its_file_single_bank() {
    let p = project(MAIN);
    let (r, _) = build_m6809(&p.path().join("xmod.vpyproj"), p.path());
    assert!(r.ok, "build failed:\n{}", r.output);
    assert_pdb_attributes_imported_lines(&p.path().join("out.pdb"));
}

#[test]
fn pdb_points_imported_code_at_its_file_multibank() {
    // The META lines shift main.vpy by 3 lines: main line 11 becomes 14.
    let p = project(&format!("{MULTIBANK_META}{MAIN}"));
    let (r, _) = build_m6809(&p.path().join("xmod.vpyproj"), p.path());
    assert!(r.ok, "multibank build failed:\n{}", r.output);
    let pdb: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(p.path().join("out.pdb")).expect("pdb written")).unwrap();
    let lines = pdb_lines(&pdb);
    assert!(lines.contains(&("physics.vpy".to_string(), 7)), "{lines:?}");
    assert!(lines.contains(&("main.vpy".to_string(), 14)), "{lines:?}");
    assert_eq!(pdb["functions"]["PHYSICS_STEP"]["file"], "physics.vpy");
}

#[test]
fn pdb_of_a_lone_file_maps_everything_to_it() {
    // Backward compatible shape: one file, lineMap == fileLineMap[file].
    let tmp = tempfile::tempdir().unwrap();
    let main = tmp.path().join("solo.vpy");
    std::fs::write(&main, "def main():\n    SET_INTENSITY(127)\n\ndef loop():\n    DRAW_LINE(0, 0, 10, 0, 127)\n").unwrap();
    let (r, _) = build_m6809(&main, tmp.path());
    assert!(r.ok, "build failed:\n{}", r.output);
    let pdb: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(tmp.path().join("out.pdb")).unwrap()).unwrap();
    assert!(pdb_lines(&pdb).iter().all(|(f, _)| f == "solo.vpy"));
    assert_eq!(pdb["lineMap"].as_object().unwrap(), pdb["fileLineMap"]["solo.vpy"].as_object().unwrap());
}

#[test]
fn arm_len_matches_m6809() {
    let ok = project(&MAIN.replace("    DRAW_LINE(0, 0, px, 0, 127)\n", "    px = px + len(physics.table)\n    DRAW_LINE(0, 0, px, 0, 127)\n"));
    let bad = project(&MAIN.replace("    DRAW_LINE(0, 0, px, 0, 127)\n", "    px = len(px) + len(px + 1)\n"));
    for target in ["rp2350", "uvm2", "pitrex"] {
        let (r, asm) = asm_for(&ok.path().join("xmod.vpyproj"), target, ok.path());
        assert!(r.ok, "{target}: len(global array) must build:\n{}", r.output);
        assert!(asm.contains("=ARRAY_PHYSICS_TABLE_LEN"), "{target}: compile-time length");
        assert!(!asm.contains("vpy_len") && !asm.contains("pitrex_len"), "{target}: no runtime stub");
        let (r, _) = asm_for(&bad.path().join("xmod.vpyproj"), target, bad.path());
        assert!(!r.ok, "{target}: len(non-array) must fail:\n{}", r.output);
        assert!(r.output.contains(&format!("main.vpy:16: error: len(px) is not supported on {target}")),
            "{target}: {}", r.output);
        assert!(r.output.contains(&format!("main.vpy:16: error: len() on {target} needs the name of a global array")), "{target}: {}", r.output);
    }
}

/// A project of the given `src/` files.
fn project_of(files: &[(&str, &str)]) -> tempfile::TempDir {
    let tmp = tempfile::tempdir().unwrap();
    let dir = tmp.path();
    std::fs::create_dir_all(dir.join("src")).unwrap();
    std::fs::write(
        dir.join("xmod.vpyproj"),
        "[project]\nname = \"xmod\"\nversion = \"0.1.0\"\nentry = \"src/main.vpy\"\n\n[sources]\nvpy = [\"src/**/*.vpy\"]\n",
    )
    .unwrap();
    for (name, text) in files {
        std::fs::write(dir.join("src").join(name), text).unwrap();
    }
    tmp
}

const TYPES: &str = "\
enum Stage:
    S_SPACE
    S_TRENCH

struct Tie:
    x: i16
    hp: u8 = 3

ties = Tie[4]
";

#[test]
fn struct_types_enums_and_arrays_cross_modules() {
    // A struct type used from another module three ways: module.Type[n],
    // `from m import Type`, module.Type(values).
    let space = "\
import types
from types import Tie, S_TRENCH

bolts = types.Tie[2]
boss = types.Tie(5, 9)
more = Tie[3]
stage = 0

def hit(i):
    types.ties[i].hp -= 1
    bolts[1].x = boss.hp + more[2].hp
    stage = S_TRENCH
";
    let main = "\
import space

def main():
    space.hit(2)

def loop():
    pass
";
    let p = project_of(&[("main.vpy", main), ("space.vpy", space), ("types.vpy", TYPES)]);
    let proj = p.path().join("xmod.vpyproj");
    let (r, asm) = build_m6809(&proj, p.path());
    assert!(r.ok, "m6809:\n{}", r.output);
    for global in ["TYPES_TIES__HP", "SPACE_BOLTS__X", "SPACE_BOSS__HP", "SPACE_MORE__HP"] {
        assert!(asm.contains(&format!("VAR_{global}")), "m6809: no {global}");
    }
    for target in ["rp2350", "uvm2", "pitrex"] {
        let (r, _) = asm_for(&proj, target, p.path());
        assert!(r.ok, "{target}:\n{}", r.output);
    }
}

#[test]
fn codegen_errors_name_the_module_file_and_the_written_names() {
    // A codegen error inside an imported module names that file, not "line N",
    // and a struct field as written (`ties.x`), not its global (`TYPES_ties__x`).
    let types = TYPES.replace("    x: i16", "    x: i32");
    let space = "def frame():\n    nope_fn(1)\n";
    let main = "import space\nimport types\n\ndef main():\n    pass\n\ndef loop():\n    space.frame()\n";
    let p = project_of(&[("main.vpy", main), ("space.vpy", space), ("types.vpy", &types)]);
    let proj = p.path().join("xmod.vpyproj");
    let (r, _) = build_m6809(&proj, p.path());
    assert!(!r.ok);
    assert!(r.output.contains("types.vpy:9: error: `ties.x: i32`"), "{}", r.output);
    let ok_types = TYPES.to_string();
    let p = project_of(&[("main.vpy", main), ("space.vpy", space), ("types.vpy", &ok_types)]);
    let proj = p.path().join("xmod.vpyproj");
    for target in ["m6809", "rp2350", "uvm2", "pitrex"] {
        let r = if target == "m6809" { build_m6809(&proj, p.path()).0 } else { asm_for(&proj, target, p.path()).0 };
        assert!(!r.ok, "{target} must fail");
        assert!(r.output.contains("space.vpy:2: error: `NOPE_FN()` is not a builtin"), "{target}: {}", r.output);
    }
}
