//! Reproducible builds: the same project, built several times in one process, must give
//! byte-identical ROMs (multibank and single-bank).
//!
//! Each `HashMap`/`HashSet` gets its own random seed, so building repeatedly in-process
//! shakes out any emission order that follows hash iteration. The project covers the paths
//! that did: assets distributed across switchable banks (legacy ASSET_*_TABLE order),
//! animation-referenced vecs emitted into the helpers bank, per-animation RAM state
//! (DRAW_ANIM), and user functions split across banks (cross-bank trampolines).
//!
//! Phases 2 → 3 → 5 → 6/7: parse, unify, generate, assemble + link, the same calls
//! `vpy_cli build` makes.

use std::collections::HashMap;
use std::path::{Path, PathBuf};

const ROM_SIZE: usize = 65536;
const BANK_SIZE: usize = 16384;
const BUILDS: usize = 4;

fn include_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../ide/frontend/public/include")
}

fn scratch_dir(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "vpy_multibank_determinism_{}_{}",
        std::process::id(),
        tag
    ));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).expect("create scratch dir");
    dir
}

fn vec_json(name: &str, size: i32) -> String {
    format!(
        r#"{{"version":"1.0","name":"{name}","canvas":{{"width":256,"height":256,"origin":"center"}},
"layers":[{{"name":"default","visible":true,"paths":[
{{"name":"a","intensity":127,"closed":true,"points":[{{"x":{n},"y":{n}}},{{"x":{s},"y":{n}}},{{"x":{s},"y":{s}}},{{"x":{n},"y":{s}}}]}},
{{"name":"b","intensity":100,"closed":false,"points":[{{"x":0,"y":{n}}},{{"x":0,"y":{s}}}]}}]}}]}}"#,
        n = -size,
        s = size
    )
}

fn vanim_json(name: &str, refs: &[&str]) -> String {
    let frames: Vec<String> = refs
        .iter()
        .enumerate()
        .map(|(i, r)| format!(r#"{{"index":{i},"duration_ticks":4,"vec_refs":["{r}"]}}"#))
        .collect();
    format!(
        r#"{{"version":"1.0","name":"{name}","loop":true,"base_refs":[],"frames":[{}]}}"#,
        frames.join(",")
    )
}

/// Writes the project: src/main.vpy + assets/vectors/*.vec + assets/animations/*.vanim.
/// `lines_per_helper` sizes the code: big enough and bank 0 overflows into the switchable
/// banks (multibank); small, and it all fits a 32 KB cartridge (single-bank).
fn write_project(root: &Path, multibank: bool, lines_per_helper: usize) -> PathBuf {
    let vectors = root.join("assets/vectors");
    let anims = root.join("assets/animations");
    std::fs::create_dir_all(&vectors).unwrap();
    std::fs::create_dir_all(&anims).unwrap();
    std::fs::create_dir_all(root.join("src")).unwrap();

    // Animation frames (kept in the helpers bank) and free-standing sprites (distributed).
    let frame_names: Vec<String> = (0..8).map(|i| format!("frame_{i}")).collect();
    let sprite_names: Vec<String> = (0..10).map(|i| format!("sprite_{i}")).collect();
    for (i, n) in frame_names.iter().chain(sprite_names.iter()).enumerate() {
        std::fs::write(vectors.join(format!("{n}.vec")), vec_json(n, 4 + (i as i32 % 5))).unwrap();
    }
    let f: Vec<&str> = frame_names.iter().map(|s| s.as_str()).collect();
    std::fs::write(anims.join("walk.vanim"), vanim_json("walk", &f[0..4])).unwrap();
    std::fs::write(anims.join("idle.vanim"), vanim_json("idle", &f[4..8])).unwrap();
    std::fs::write(anims.join("jump.vanim"), vanim_json("jump", &[f[0], f[5]])).unwrap();

    let mut src = if multibank {
        format!("META ROM_TOTAL_SIZE = {ROM_SIZE}\nMETA ROM_BANK_SIZE = {BANK_SIZE}\n\n")
    } else {
        String::new()
    };
    src.push_str("x = 0\ny = 0\nmode = 0\n\n");
    src.push_str("def main():\n    SET_INTENSITY(127)\n\n");
    src.push_str("def loop():\n    mode = (mode + 1) % 3\n");
    src.push_str("    if mode == 0:\n        DRAW_ANIM(\"walk\", x, y, 0)\n");
    src.push_str("    if mode == 1:\n        DRAW_ANIM(\"idle\", x, y, 1)\n");
    src.push_str("    if mode == 2:\n        DRAW_ANIM(\"jump\", x, y, 0)\n");
    for i in 0..sprite_names.len() {
        src.push_str(&format!("    draw_{i}()\n"));
    }
    src.push('\n');
    for (i, n) in sprite_names.iter().enumerate() {
        src.push_str(&format!("def draw_{i}():\n    DRAW_VECTOR(\"{n}\", {}, {})\n", i * 3, i * 2));
        // Calls between the generated functions, so some cross a bank boundary.
        src.push_str(&format!("    helper_{i}({i})\n"));
        src.push('\n');
        // Enough code per function that bank 0 overflows and the allocator spreads the
        // functions over the switchable banks.
        src.push_str(&format!("def helper_{i}(v):\n"));
        // ...and from the switchable banks into each other. Only forward calls: m6809
        // has no recursion (parameters live at fixed RAM addresses), so no call cycle.
        if i + 3 < sprite_names.len() {
            src.push_str(&format!("    if v > 100:\n        helper_{}(v - 1)\n", i + 3));
        }
        for k in 0..lines_per_helper {
            src.push_str(&format!(
                "    x = x + v * {k}\n    if x > {lim}:\n        y = y - {k}\n        x = 0\n",
                lim = 50 + k
            ));
        }
        src.push('\n');
    }
    let main = root.join("src/main.vpy");
    std::fs::write(&main, src).unwrap();
    main
}

fn build_rom(main: &Path, out_dir: &Path) -> Vec<u8> {
    let src = std::fs::read_to_string(main).unwrap();
    let tokens = vpy_parser::lex(&src).expect("lex");
    let module = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = HashMap::new();
    modules.insert("main".to_string(), module);
    let unified = vpy_unifier::unify_modules(modules, "main").expect("unify");

    let assets = vpy_codegen::m6809::assets::discover_assets(main);
    let config = vpy_codegen::BankConfig::new(ROM_SIZE, BANK_SIZE);
    // generate → measure → regenerate, as `vpy_cli build` does for multibank.
    let generated = vpy_linker::sizing::generate_m6809(&unified, &config, "DETERMINISM", &assets, Some(include_dir()))
        .expect("codegen");

    std::fs::create_dir_all(out_dir).unwrap();
    let asm_path = out_dir.join("game.asm");
    let bin_path = out_dir.join("game.bin");
    std::fs::write(&asm_path, &generated.asm_source).unwrap();
    let linker = vpy_linker::MultiBankLinker::new(
        BANK_SIZE as u32,
        (ROM_SIZE / BANK_SIZE) as u8,
        true,
        Some(include_dir()),
    );
    linker.generate_multibank_rom(&asm_path, &bin_path).expect("multibank link");
    std::fs::read(&bin_path).expect("read ROM")
}

fn build_single_bank_rom(main: &Path) -> Vec<u8> {
    let src = std::fs::read_to_string(main).unwrap();
    let tokens = vpy_parser::lex(&src).expect("lex");
    let module = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = HashMap::new();
    modules.insert("main".to_string(), module);
    let unified = vpy_unifier::unify_modules(modules, "main").expect("unify");

    let assets = vpy_codegen::m6809::assets::discover_assets(main);
    let config = vpy_codegen::BankConfig::single_bank();
    let generated = vpy_codegen::generate_from_module(&unified, &config, "DETERMINISM", &assets)
        .expect("codegen");
    let sections = vpy_assembler::parse_unified_asm(&generated.asm_source).expect("bank sections");
    vpy_assembler::set_include_dir(Some(include_dir()));
    let binaries = vpy_assembler::assemble_banks(sections).expect("assemble");
    vpy_linker::link_unified_asm(&generated, binaries).expect("link").rom_data
}

fn assert_same_bytes(first: &[u8], again: &[u8], build: usize) {
    assert_eq!(again.len(), first.len(), "build {build}: ROM size changed");
    if let Some(pos) = first.iter().zip(again).position(|(a, b)| a != b) {
        panic!(
            "build {build} differs from build 0 at ${pos:05X} (bank {}, offset ${:04X}): \
             the emission order depends on hash iteration",
            pos / BANK_SIZE,
            pos % BANK_SIZE
        );
    }
}

#[test]
fn test_single_bank_build_is_reproducible() {
    let root = scratch_dir("single");
    let main = write_project(&root, false, 2);
    let first = build_single_bank_rom(&main);
    assert!(!first.is_empty(), "a ROM");
    for i in 1..BUILDS {
        assert_same_bytes(&first, &build_single_bank_rom(&main), i);
    }
    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn test_multibank_build_is_reproducible() {
    let root = scratch_dir("project");
    let main = write_project(&root, true, 30);

    let first = build_rom(&main, &root.join("out_0"));
    assert_eq!(first.len(), ROM_SIZE, "a full multibank ROM");
    for i in 1..BUILDS {
        let again = build_rom(&main, &root.join(format!("out_{i}")));
        assert_same_bytes(&first, &again, i);
    }
    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn test_multibank_link_error_is_reported_not_written() {
    // Error case: an ASM the multibank linker cannot link (here: no bank markers, so no
    // helpers bank) must come back as an error, never as a ROM file.
    let root = scratch_dir("error");
    let asm_path = root.join("broken.asm");
    let bin_path = root.join("broken.bin");
    std::fs::write(&asm_path, "    ORG $0000\nSTART:\n    JSR NOWHERE_DEFINED\n").unwrap();
    let linker = vpy_linker::MultiBankLinker::new(BANK_SIZE as u32, 4, true, Some(include_dir()));
    let result = linker.generate_multibank_rom(&asm_path, &bin_path);
    assert!(result.is_err(), "an unlinkable ASM must be an error");
    assert!(!bin_path.exists(), "no ROM may be written for a failed link");
    let _ = std::fs::remove_dir_all(&root);
}
