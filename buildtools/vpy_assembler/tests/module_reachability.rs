//! Guard: every `.rs` file under a crate's `src/` must be reachable from `lib.rs`/`main.rs`
//! through `mod` declarations (or a `#[path = "..."]` attribute).
//!
//! A file nobody declares is never compiled, so its `#[test]` functions silently never run.
//! That is how vpy_assembler ran 0 unit tests while `parser.rs`, `expression.rs` and
//! `symbols.rs` held 10 of them. This check scans the whole buildtools workspace.

use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};

/// Known orphans in crates owned by other work streams. Remove an entry once the file
/// is wired in (with `mod`) or deleted. Do NOT add new entries to silence this test.
const KNOWN_ORPHANS: &[&str] = &[
    "vpy_codegen/src/context.rs",
    "vpy_codegen/src/emitter.rs",
    "vpy_codegen/src/error.rs",
    "vpy_codegen/src/ir.rs",
    "vpy_codegen/src/path_ordering.rs",
];

fn rs_files(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let p = entry.path();
        if p.is_dir() {
            rs_files(&p, out);
        } else if p.extension().is_some_and(|e| e == "rs") {
            out.push(p);
        }
    }
}

/// True if `text` contains `mod <name>;` or `mod <name> {` (with any visibility/attrs).
fn declares_mod(text: &str, name: &str) -> bool {
    text.lines().any(|line| {
        let line = line.trim();
        let Some(idx) = line.find("mod ") else { return false };
        if idx > 0 && !line[..idx].ends_with(' ') && !line[..idx].ends_with(')') {
            return false;
        }
        let rest = line[idx + 4..].trim_start();
        let rest = rest.strip_prefix("r#").unwrap_or(rest);
        rest.strip_prefix(name)
            .map(|after| {
                let after = after.trim_start();
                after.starts_with(';') || after.starts_with('{')
            })
            .unwrap_or(false)
    })
}

fn orphans_in_crate(workspace: &Path, crate_dir: &Path) -> Vec<String> {
    let src = crate_dir.join("src");
    let mut files = Vec::new();
    rs_files(&src, &mut files);
    let texts: Vec<(PathBuf, String)> = files
        .iter()
        .map(|p| (p.clone(), fs::read_to_string(p).unwrap_or_default()))
        .collect();
    let text_of = |p: &Path| {
        texts.iter().find(|(q, _)| q == p).map(|(_, t)| t.as_str()).unwrap_or("")
    };

    let mut orphans = Vec::new();
    for file in &files {
        let parent_dir = file.parent().unwrap();
        // Crate roots and cargo auto-discovered binaries.
        if (parent_dir == src && (file.ends_with("lib.rs") || file.ends_with("main.rs")))
            || parent_dir == src.join("bin")
            || parent_dir.parent() == Some(&src.join("bin"))
        {
            continue;
        }
        let file_name = file.file_name().unwrap().to_string_lossy().to_string();
        let (mod_name, owner_dir) = if file_name == "mod.rs" {
            (
                parent_dir.file_name().unwrap().to_string_lossy().to_string(),
                parent_dir.parent().unwrap().to_path_buf(),
            )
        } else {
            (file_name.trim_end_matches(".rs").to_string(), parent_dir.to_path_buf())
        };
        let parents: Vec<PathBuf> = if owner_dir == src {
            vec![src.join("lib.rs"), src.join("main.rs")]
        } else {
            vec![owner_dir.join("mod.rs"), owner_dir.with_extension("rs")]
        };
        let declared = parents.iter().any(|p| declares_mod(text_of(p), &mod_name));
        let path_attr = format!("\"{}\"", file_name);
        let via_path = texts
            .iter()
            .any(|(_, t)| t.lines().any(|l| l.contains("#[path") && l.contains(&path_attr)));
        if !declared && !via_path {
            let rel = file.strip_prefix(workspace).unwrap_or(file);
            orphans.push(rel.to_string_lossy().replace('\\', "/"));
        }
    }
    orphans
}

#[test]
fn test_workspace_every_source_file_is_compiled() {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let workspace = crate_dir.parent().expect("workspace dir");

    let mut found = BTreeSet::new();
    let mut crates_scanned = 0;
    for entry in fs::read_dir(workspace).expect("read workspace").flatten() {
        let dir = entry.path();
        if dir.join("Cargo.toml").exists() && dir.join("src").is_dir() {
            crates_scanned += 1;
            found.extend(orphans_in_crate(workspace, &dir));
        }
    }
    assert!(crates_scanned >= 10, "expected to scan the buildtools crates, got {}", crates_scanned);

    let known: BTreeSet<String> = KNOWN_ORPHANS.iter().map(|s| s.to_string()).collect();
    let new_orphans: Vec<_> = found.difference(&known).collect();
    assert!(
        new_orphans.is_empty(),
        "source files not reachable from lib.rs/main.rs (never compiled, their tests never run): {:?}\n\
         Declare them with `mod` or delete them.",
        new_orphans
    );
    let fixed: Vec<_> = known.difference(&found).collect();
    assert!(
        fixed.is_empty(),
        "these KNOWN_ORPHANS are no longer orphans; remove them from the list: {:?}",
        fixed
    );
}

#[test]
fn test_vpy_assembler_unit_test_module_is_wired() {
    // The helper tests must stay attached to asm_to_binary.rs.
    let src = Path::new(env!("CARGO_MANIFEST_DIR")).join("src/m6809/asm_to_binary.rs");
    let text = fs::read_to_string(src).expect("read asm_to_binary.rs");
    assert!(text.contains("#[path = \"asm_to_binary_tests.rs\"]"));
    assert!(text.contains("#[cfg(test)]"));
}

#[test]
fn test_declares_mod_matches_forms() {
    assert!(declares_mod("pub mod parser;", "parser"));
    assert!(declares_mod("mod tests {", "tests"));
    assert!(declares_mod("pub(crate) mod x;", "x"));
    assert!(!declares_mod("pub mod parser_ext;", "parser"));
    assert!(!declares_mod("// see the parser mod", "parser"));
}
