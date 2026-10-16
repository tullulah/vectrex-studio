//! DRAW_VECTOR_ROT("name", x, y, angle [, mirror [, intensity]]) on the ARM
//! targets (rp2350, uvm2: inline Thumb-2 runtime; pitrex: libvpy's
//! vpy_draw_vector_rot_ex) and the shared argument / asset checks. The m6809
//! cases live in `src/m6809/regression_tests.rs`.

use vpy_codegen::{AssetInfo, AssetType, BankConfig, Target};

const ELL_VEC: &str = r#"{"version":"1.0","name":"ell","canvas":{"width":256,"height":256,"origin":"center"},
 "layers":[{"name":"default","visible":true,"paths":[
  {"name":"l","intensity":100,"closed":false,"points":[{"x":-20,"y":-10},{"x":20,"y":-10},{"x":20,"y":10}]}]}]}"#;

const SRC: &str = "\
angle = 0

def main():
    SET_INTENSITY(127)

def loop():
    DRAW_VECTOR_ROT(\"ell\", 30, 20, angle)
    DRAW_VECTOR_ROT(\"ell\", -40, -30, angle, 1, 50)
    angle = angle + 1
";

fn module(src: &str) -> vpy_parser::Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

fn assets(dir: &std::path::Path) -> Vec<AssetInfo> {
    let path = dir.join("ell.vec");
    std::fs::write(&path, ELL_VEC).unwrap();
    vec![AssetInfo { name: "ell".into(), path: path.display().to_string(), asset_type: AssetType::Vector }]
}

fn generate(src: &str, target: Target) -> Result<String, String> {
    let dir = std::env::temp_dir().join(format!("vpy_rot_it_{}_{:?}", std::process::id(), target));
    std::fs::create_dir_all(&dir).unwrap();
    let bank = if matches!(target, Target::PiTrex) { BankConfig::pitrex() } else { BankConfig::single_bank() };
    vpy_codegen::generate_from_module_with_target(&module(src), &bank, "T", &assets(&dir), &target)
        .map(|g| g.asm_source)
        .map_err(|e| e.to_string())
}

#[test]
fn thumb2_targets_emit_the_runtime_once_and_call_it() {
    for target in [Target::Rp2350, Target::Uvm2] {
        let asm = generate(SRC, target.clone()).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        assert!(asm.contains("\nvpy_draw_vector_rot:\n"), "{target:?}: runtime missing");
        assert_eq!(asm.matches("bl      vpy_draw_vector_rot\n").count(), 2, "{target:?}");
        assert!(asm.contains("ldr     r0, =_ELL_VECTORS"), "{target:?}: asset path table");
        // The sin table is reached through the SIN_TABLE group and read once per call.
        assert!(asm.contains("_SIN_TABLE:"), "{target:?}: _SIN_TABLE not emitted");
        let rt = &asm[asm.find("\nvpy_draw_vector_rot:\n").unwrap()..];
        let rt = &rt[..rt.find("dvr_pl:").unwrap()];
        assert_eq!(rt.matches("ldrsb   r1, [r0, r3]").count(), 2, "{target:?}: sin + cos once per call");
        // Explicit intensity/mirror on the second call; the frame override on the first.
        assert!(asm.contains("ldr     r0, =VPY_BRIGHTNESS_OVERRIDE\n    ldrb    r0, [r0]\n    push    {r0}"));
    }
}

#[test]
fn pitrex_calls_libvpy_on_the_position_independent_image() {
    let asm = generate(SRC, Target::PiTrex).unwrap_or_else(|e| panic!("{e}"));
    assert_eq!(asm.matches("bl      vpy_draw_vector_rot_ex\n").count(), 2);
    assert!(asm.contains("ldr     r0, =_ELL_VEC    @ asset 'ell' (libvpy image)"));
    assert!(asm.contains("\n_ELL_VEC:\n"), "libvpy .vec image not emitted");
}

#[test]
fn unknown_asset_and_bad_arity_are_errors_on_every_arm_target() {
    let unknown = "def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR_ROT(\"ship\", 0, 0, 8)\n";
    let arity = "def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR_ROT(\"ell\", 0, 0)\n";
    for target in [Target::Rp2350, Target::Uvm2, Target::PiTrex] {
        let e = generate(unknown, target.clone()).expect_err("unknown asset");
        assert!(e.contains("line 5") && e.contains("no vector asset named 'ship'"), "{target:?}: {e}");
        let e = generate(arity, target.clone()).expect_err("3 args");
        assert!(e.contains("line 5") && e.contains("takes 4 to 6 arguments"), "{target:?}: {e}");
    }
}

#[test]
fn a_missing_vec_is_an_error_with_its_line_for_every_vector_builtin_and_target() {
    // A sprite whose .vec is not in the project used to reach the assembler as an
    // undefined `_NAME_PATH0` (m6809) or a failed link (ARM), with no line.
    let calls = [
        "DRAW_VECTOR(\"text\", 0, -44)",
        "DRAW_VECTOR_EX(\"text\", 0, 0, 1, 100)",
        "DRAW_VECTOR_3D(\"text\", 0, 0, 0, 0, 60)",
    ];
    for call in calls {
        let src = format!("def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR(\"ell\", 0, 0)\n    {call}\n");
        for target in [Target::M6809, Target::Rp2350, Target::Uvm2, Target::PiTrex] {
            let e = generate(&src, target.clone()).expect_err("missing .vec");
            assert!(
                e.contains("line 6") && e.contains("no vector asset named 'text'") && e.contains("available: ell"),
                "{target:?} {call}: {e}"
            );
        }
    }
    // The asset that is there still builds.
    let ok = "def main():\n    pass\n\ndef loop():\n    DRAW_VECTOR(\"ell\", 0, 0)\n";
    for target in [Target::M6809, Target::Rp2350, Target::Uvm2, Target::PiTrex] {
        generate(ok, target.clone()).unwrap_or_else(|e| panic!("{target:?}: {e}"));
    }
}
