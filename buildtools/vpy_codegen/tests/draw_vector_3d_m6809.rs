//! m6809 DRAW_VECTOR_3D runtime hardening. DV3D_ROTATE's intermediates
//! (y1, z1, x2) are the SMUL_LUT operands of the next rotation stage, and the
//! product table only covers |val| <= 63. A model tumbled on two or three axes
//! used to push them past the table — the LUT then read past SMUL_PROD and the
//! vertex streaked to a screen edge (or wrapped its i8 sign past ±127). The
//! runtime now clamps the intermediates to ±63, saturates the screen sums to
//! ±127, and masks the angles to the 0-127 table column range.

use vpy_codegen::{AssetInfo, AssetType, BankConfig, Target};

/// Small 3D wireframe (z on one point) plus one vertex past the ±63 data clamp.
const CUBE_VEC: &str = r#"{"version":"1.0","name":"cube","canvas":{"width":256,"height":256,"origin":"center"},
 "layers":[{"name":"default","visible":true,"paths":[
  {"name":"sq","intensity":100,"closed":true,"points":[
    {"x":-40,"y":-40,"z":40},{"x":100,"y":-40,"z":40},{"x":40,"y":40,"z":-40},{"x":-40,"y":40,"z":-40}]}]}]}"#;

const SRC: &str = "\
ax = 0

def main():
    SET_INTENSITY(127)

def loop():
    DRAW_VECTOR_3D(\"cube\", ax, 32, 96, 10, -20)
    ax = ax + 1
";

fn module(src: &str) -> vpy_parser::Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

fn assets(dir: &std::path::Path) -> Vec<AssetInfo> {
    let path = dir.join("cube.vec");
    std::fs::write(&path, CUBE_VEC).unwrap();
    vec![AssetInfo { name: "cube".into(), path: path.display().to_string(), asset_type: AssetType::Vector }]
}

fn generate(src: &str) -> String {
    let dir = std::env::temp_dir().join(format!("vpy_dv3d_it_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    vpy_codegen::generate_from_module_with_target(
        &module(src),
        &BankConfig::single_bank(),
        "T",
        &assets(&dir),
        &Target::M6809,
    )
    .map(|g| g.asm_source)
    .unwrap_or_else(|e| panic!("{e}"))
}

#[test]
fn dv3d_clamps_every_rotation_intermediate_to_the_smul_lut_range() {
    let asm = generate(SRC);
    for n in 0..3 {
        assert!(asm.contains(&format!("DV3D_CL{n}_HI:\n")), "clamp site {n} missing");
        assert!(asm.contains(&format!("DV3D_CL{n}_OK:\n")), "clamp site {n} missing");
    }
    // One clamp sequence (CMPA #$3F / CMPA #$C1) per intermediate: y1, z1, x2.
    assert_eq!(asm.matches("CMPA #$3F").count(), 3, "clamp compares");
    assert_eq!(asm.matches("CMPA #$C1").count(), 3, "clamp compares");
}

#[test]
fn dv3d_saturates_screen_sums_and_masks_angles() {
    let asm = generate(SRC);
    assert!(asm.contains("DV3D_SX_OK:\n"), "X saturation missing");
    assert!(asm.contains("DV3D_SY_OK:\n"), "Y saturation missing");
    for reg in ["ROT3D_AX", "ROT3D_AY", "ROT3D_AZ"] {
        assert!(
            asm.contains(&format!("ANDA #$7F\nSTA >{reg}")),
            "angle {reg} not masked to 0-127"
        );
    }
}

#[test]
fn dv3d_asset_data_is_clamped_to_the_table_range() {
    // The point at x=100 must land in the 3D vertex table as 63, not 100.
    // (The 2D DRAW_VECTOR data legitimately keeps the original coordinate.)
    let asm = generate(SRC);
    let table = &asm[asm.find("_CUBE_3D_DATA:\n").expect("3D data table missing")..];
    assert!(table.contains("x=63"), "oversized vertex not clamped: {table}");
    assert!(!table.contains("x=100"), "unclamped coordinate in vertex table");
}
