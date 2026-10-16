//! End-to-end regressions for m6809 vector-asset path labels.
//!
//! The single-bank DRAW_VECTOR / DRAW_VECTOR_EX code unrolls one
//! `LDX #_<NAME>_PATHn` per path, while the asset data (`_<NAME>_PATH0..N-1`)
//! comes from `VecResource::compile_to_asm_with_name`. Both must count the same
//! list (`m6809_emitted_paths`): reordered, degenerate paths dropped and
//! contiguous open polylines fused. When the call site counted the paths before
//! fusion it named labels that were never emitted (`Undefined symbol:
//! _LOGO_PATH6`).

use std::path::Path;
use std::process::Command;

const MULTIBANK_META: &str = "META ROM_TOTAL_SIZE = 65536\nMETA ROM_BANK_SIZE = 16384\n\n";

/// Two contiguous open polylines (fused into one), a 1-point path (dropped),
/// a closed square (kept) and a path on a hidden layer (ignored):
/// 5 paths in the file, 4 visible, 3 non-degenerate, 2 emitted with fusion.
const FUSING_VEC: &str = r#"{
  "version": "1.0",
  "name": "shape",
  "canvas": {"width": 256, "height": 256, "origin": "center"},
  "layers": [
    {"name": "default", "visible": true, "paths": [
      {"name": "a", "intensity": 100, "closed": false,
       "points": [{"x": -40, "y": 0}, {"x": -20, "y": 20}]},
      {"name": "b", "intensity": 100, "closed": false,
       "points": [{"x": -20, "y": 20}, {"x": 0, "y": 0}]},
      {"name": "dot", "intensity": 100, "closed": false,
       "points": [{"x": 5, "y": 5}]},
      {"name": "box", "intensity": 80, "closed": true,
       "points": [{"x": 20, "y": -10}, {"x": 40, "y": -10}, {"x": 40, "y": 10}, {"x": 20, "y": 10}]}
    ]},
    {"name": "hidden", "visible": false, "paths": [
      {"name": "h", "intensity": 100, "closed": false,
       "points": [{"x": 0, "y": 0}, {"x": 10, "y": 10}]}
    ]}
  ]
}"#;

/// Only degenerate paths: the asset emits no `_PATHn` labels at all.
const DEGENERATE_VEC: &str = r#"{
  "version": "1.0",
  "name": "dots",
  "canvas": {"width": 256, "height": 256, "origin": "center"},
  "layers": [
    {"name": "default", "visible": true, "paths": [
      {"name": "p", "intensity": 100, "closed": false, "points": [{"x": 0, "y": 0}]},
      {"name": "q", "intensity": 100, "closed": false, "points": []}
    ]}
  ]
}"#;

const DRAW_SRC: &str = "\
def main():
    SET_INTENSITY(127)

def loop():
    DRAW_VECTOR(\"shape\", 0, 0)
    DRAW_VECTOR_EX(\"shape\", 10, -10, 1, 90)
";

struct Build {
    ok: bool,
    output: String,
    asm: String,
}

fn build(dir: &Path, name: &str, src: &str, env: &[(&str, &str)]) -> Build {
    let source = dir.join(format!("{name}.vpy"));
    std::fs::write(&source, src).expect("write source");
    let bin = dir.join(format!("{name}.bin"));
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_vpy_cli"));
    cmd.arg("build")
        .arg(&source)
        .args(["--target", "m6809", "-o"])
        .arg(&bin)
        .current_dir(dir)
        .env_remove("VPY_VEC_MERGE_PATHS")
        .env_remove("VPY_VEC_MERGE_MAX_SEGS");
    for (k, v) in env {
        cmd.env(k, v);
    }
    let out = cmd.output().expect("run vpy_cli");
    let output = format!(
        "{}{}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    let asm = std::fs::read_to_string(bin.with_extension("asm")).unwrap_or_default();
    Build { ok: out.status.success() && bin.exists(), output, asm }
}

fn project(vecs: &[(&str, &str)]) -> tempfile::TempDir {
    let dir = tempfile::tempdir().expect("tempdir");
    let vdir = dir.path().join("assets").join("vectors");
    std::fs::create_dir_all(&vdir).expect("assets dir");
    for (name, body) in vecs {
        std::fs::write(vdir.join(format!("{name}.vec")), body).expect("write .vec");
    }
    dir
}

fn label_defined(asm: &str, label: &str) -> bool {
    let want = format!("{label}:");
    asm.lines().any(|l| l.trim_end() == want || l.starts_with(&format!("{want} ")))
}

/// Path count from the asset header line `_<SYM>_VECTORS:` + `FDB n`.
fn header_path_count(asm: &str, sym: &str) -> usize {
    let head = format!("_{sym}_VECTORS:");
    let mut lines = asm.lines().skip_while(|l| !l.starts_with(&head));
    lines.next().expect("asset header emitted");
    let fdb = lines.next().expect("path_count line");
    fdb.trim()
        .trim_start_matches("FDB")
        .split_whitespace()
        .next()
        .and_then(|n| n.parse().ok())
        .unwrap_or_else(|| panic!("unparsable path_count line: {fdb}"))
}

/// Every `LDX #_<SYM>_PATHn` names a defined label; returns how many there are.
fn check_path_refs(asm: &str, sym: &str) -> usize {
    let prefix = format!("LDX #_{sym}_PATH");
    let mut refs = 0;
    for line in asm.lines() {
        if let Some(rest) = line.trim().strip_prefix(&prefix) {
            let n: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
            let label = format!("_{sym}_PATH{n}");
            assert!(label_defined(asm, &label), "{label} referenced but not emitted");
            refs += 1;
        }
    }
    refs
}

#[test]
fn single_bank_draw_vector_names_only_emitted_paths() {
    let dir = project(&[("shape", FUSING_VEC)]);
    let b = build(dir.path(), "vecpaths", DRAW_SRC, &[]);
    assert!(b.ok, "single-bank build failed:\n{}", b.output);
    assert_eq!(header_path_count(&b.asm, "SHAPE"), 2, "fused + degenerate-filtered count");
    assert!(label_defined(&b.asm, "_SHAPE_PATH1"));
    assert!(!label_defined(&b.asm, "_SHAPE_PATH2"));
    // DRAW_VECTOR and DRAW_VECTOR_EX each unroll exactly path_count loads.
    assert_eq!(check_path_refs(&b.asm, "SHAPE"), 2 * 2);
}

#[test]
fn single_bank_counts_match_with_fusion_disabled() {
    let dir = project(&[("shape", FUSING_VEC)]);
    let b = build(dir.path(), "vecpaths_nofuse", DRAW_SRC, &[("VPY_VEC_MERGE_PATHS", "0")]);
    assert!(b.ok, "single-bank build without fusion failed:\n{}", b.output);
    assert_eq!(header_path_count(&b.asm, "SHAPE"), 3);
    assert_eq!(check_path_refs(&b.asm, "SHAPE"), 2 * 3);
}

#[test]
fn single_bank_counts_match_with_low_fusion_cap() {
    // Cap 2 segments: the two 1-segment polylines still fuse (1+1 <= 2).
    // Cap is clamped to >= 2, so this exercises the env-driven cap path.
    let dir = project(&[("shape", FUSING_VEC)]);
    let b = build(dir.path(), "vecpaths_cap", DRAW_SRC, &[("VPY_VEC_MERGE_MAX_SEGS", "2")]);
    assert!(b.ok, "single-bank build with cap 2 failed:\n{}", b.output);
    let n = header_path_count(&b.asm, "SHAPE");
    assert_eq!(check_path_refs(&b.asm, "SHAPE"), 2 * n);
}

#[test]
fn multibank_draw_vector_links() {
    let dir = project(&[("shape", FUSING_VEC)]);
    let src = format!("{MULTIBANK_META}{DRAW_SRC}");
    let b = build(dir.path(), "vecpaths_mb", &src, &[]);
    assert!(b.ok, "multibank build failed:\n{}", b.output);
    assert!(b.output.to_lowercase().contains("multibank"), "expected multibank:\n{}", b.output);
    assert_eq!(header_path_count(&b.asm, "SHAPE"), 2);
    // Any unrolled reference that survives must still name an emitted label.
    check_path_refs(&b.asm, "SHAPE");
    for i in 0..2 {
        assert!(label_defined(&b.asm, &format!("_SHAPE_PATH{i}")));
    }
}

#[test]
fn all_degenerate_asset_emits_no_path_references() {
    let dir = project(&[("dots", DEGENERATE_VEC)]);
    let src = "\
def main():
    SET_INTENSITY(127)

def loop():
    DRAW_VECTOR(\"dots\", 0, 0)
";
    let b = build(dir.path(), "dots", src, &[]);
    assert!(b.ok, "degenerate-only asset failed to build:\n{}", b.output);
    assert_eq!(check_path_refs(&b.asm, "DOTS"), 0);
}
