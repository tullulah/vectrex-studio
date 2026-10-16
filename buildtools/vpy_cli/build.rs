//! Candidate builtin names for `vpy_cli builtins` (src/builtins_catalog.rs).
//!
//! Every backend dispatches builtins by matching the call name against string
//! literals ("DRAW_VECTOR" => ...). This script collects every UPPER_SNAKE string
//! literal of the codegen and parser sources; `vpy_cli builtins` then compiles a
//! call to each candidate for every target and keeps the ones a backend accepts.
//! A builtin added to any backend is therefore picked up without editing a list.

use std::path::{Path, PathBuf};

fn rs_files(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = std::fs::read_dir(dir) else { return };
    let mut entries: Vec<_> = entries.flatten().map(|e| e.path()).collect();
    entries.sort();
    for p in entries {
        if p.is_dir() {
            rs_files(&p, out);
        } else if p.extension().and_then(|e| e.to_str()) == Some("rs") {
            out.push(p);
        }
    }
}

/// `"NAME"` literals: a letter, then letters/digits/underscores, upper case only.
fn literals(text: &str, out: &mut std::collections::BTreeSet<String>) {
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'"' {
            let start = i + 1;
            let mut j = start;
            while j < bytes.len() && bytes[j] != b'"' && bytes[j] != b'\n' && bytes[j] != b'\\' {
                j += 1;
            }
            if j < bytes.len() && bytes[j] == b'"' {
                let s = &text[start..j];
                let ok = s.len() >= 2
                    && s.len() <= 40
                    && s.as_bytes()[0].is_ascii_uppercase()
                    && s.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'_')
                    && !s.ends_with('_');
                if ok {
                    out.insert(s.to_string());
                }
                i = j + 1;
                continue;
            }
            i = j.max(i + 1);
            continue;
        }
        i += 1;
    }
}

fn main() {
    let manifest = PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap());
    let roots = [
        manifest.join("../vpy_codegen/src"),
        manifest.join("../vpy_parser/src"),
    ];
    let mut files = Vec::new();
    for r in &roots {
        println!("cargo:rerun-if-changed={}", r.display());
        rs_files(r, &mut files);
    }
    let mut names = std::collections::BTreeSet::new();
    for f in &files {
        // Test modules name builtins too, but also arbitrary labels; they are
        // probed like the rest, so including them is harmless.
        if let Ok(text) = std::fs::read_to_string(f) {
            literals(&text, &mut names);
        }
    }
    let out = PathBuf::from(std::env::var("OUT_DIR").unwrap()).join("builtin_candidates.txt");
    let text: Vec<String> = names.into_iter().collect();
    std::fs::write(&out, text.join("\n")).unwrap();
    println!("cargo:rerun-if-changed=build.rs");
}
