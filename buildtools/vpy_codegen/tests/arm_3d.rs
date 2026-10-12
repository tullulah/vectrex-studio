//! 3D builtins (vpy3d) on the uvm2 target.
//!
//! The calls go into vpy_cli's C bridge (vpy3d_bridge.c), compiled with the
//! SDK's vpy3d.c into the image. Drawing was checked on the uvm2 emulator (a
//! rotating TIE fighter, the ds_tunnel scene with fog and occluders, PROJECT of
//! a known point); these tests pin the call ABI, the data and the errors.

use vpy_codegen::{AssetInfo, AssetType, BankConfig, Target};

const CUBE: &str = r#"{
  "name": "cube", "hard": 45,
  "vertices": [
    {"x": -100, "y": -100, "z": -100}, {"x": 100, "y": -100, "z": -100},
    {"x": 100, "y": 100, "z": -100}, {"x": -100, "y": 100, "z": -100},
    {"x": -100, "y": -100, "z": 100}, {"x": 100, "y": -100, "z": 100},
    {"x": 100, "y": 100, "z": 100}, {"x": -100, "y": 100, "z": 100}
  ],
  "faces": [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [0, 4, 7, 3]]
}"#;

const SRC: &str = "\
pose: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
spin: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
ok = 0
a = 0

def main():
    ok = LOAD_MESH(\"cube\")
    CAMERA_LOOK_AT(0, 0, -2000, 0, 0, 0)

def loop():
    a = a + 16
    XF_ROT_Y(spin, a)
    XF_TRANSLATE(pose, 0, 0, 500)
    XF_MUL(pose, pose, spin)
    DRAW_MESH(\"cube\", pose, 100)
    LINE_3D(-1, -2, -3, 4, 5, 6, 7)
";

fn module(src: &str) -> vpy_parser::Module {
    let tokens = vpy_parser::lex(src).expect("lex");
    let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
    let mut modules = std::collections::HashMap::new();
    modules.insert("main".to_string(), m);
    vpy_unifier::unify_modules(modules, "main").expect("unify")
}

/// A project directory holding `assets/meshes/cube.vmesh`.
fn cube_asset() -> (tempdir::Dir, Vec<AssetInfo>) {
    let dir = tempdir::Dir::new();
    let meshes = dir.0.join("assets/meshes/solids");
    std::fs::create_dir_all(&meshes).unwrap();
    let path = meshes.join("cube.vmesh");
    std::fs::write(&path, CUBE).unwrap();
    let assets = vec![AssetInfo { name: "cube".into(), path: path.display().to_string(), asset_type: AssetType::Mesh }];
    (dir, assets)
}

mod tempdir {
    /// A directory under the system temp dir, removed on drop.
    pub struct Dir(pub std::path::PathBuf);
    impl Dir {
        pub fn new() -> Self {
            static N: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
            let n = N.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
            let p = std::env::temp_dir().join(format!("vpy_arm3d_{}_{n}", std::process::id()));
            let _ = std::fs::remove_dir_all(&p);
            std::fs::create_dir_all(&p).unwrap();
            Dir(p)
        }
    }
    impl Drop for Dir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }
}

fn generate(src: &str, assets: &[AssetInfo], target: &Target) -> Result<String, String> {
    let bank = if matches!(target, Target::PiTrex) { BankConfig::pitrex() } else { BankConfig::single_bank() };
    vpy_codegen::generate_from_module_with_target(&module(src), &bank, "T", assets, target)
        .map(|g| g.asm_source)
        .map_err(|e| e.to_string())
}

fn instrs(asm: &str) -> Vec<String> {
    asm.lines()
        .map(|l| l.split('@').next().unwrap().split_whitespace().collect::<Vec<_>>().join(" "))
        .filter(|l| !l.is_empty())
        .collect()
}

#[test]
fn calls_follow_the_aapcs_and_the_mesh_data_is_emitted() {
    let (_dir, assets) = cube_asset();
    let asm = generate(SRC, &assets, &Target::Uvm2).unwrap();
    let code = instrs(&asm);
    for f in ["vpyx_load_mesh", "vpyx_look_at", "vpyx_xf_rot_y", "vpyx_xf_translate", "vpyx_xf_mul", "vpyx_draw_mesh", "vpyx_line_world"] {
        let at = code.iter().position(|l| *l == format!("bl {f}")).unwrap_or_else(|| panic!("no call to {f}"));
        // SP aligned to 8 around every call, r4 keeping the old SP.
        assert_eq!(&code[at - 4..at], ["push {r4}", "mov r4, sp", "bic r12, r4, #7", "mov sp, r12"], "{f}");
        assert_eq!(&code[at + 1..at + 3], ["mov sp, r4", "pop {r4}"], "{f}");
    }
    // LINE_3D: 7 arguments → r0-r3 and vpyx_args[0..2].
    let at = code.iter().position(|l| l == "bl vpyx_line_world").unwrap();
    let before = &code[..at];
    for k in [0, 4, 8] {
        assert!(before.iter().any(|l| *l == format!("str r0, [r1, #{k}]")), "vpyx_args[{}]", k / 4);
    }
    // The mesh's slot (0) and its image.
    assert!(asm.contains("_CUBE_VMESH:\n    .byte"), "mesh image");
    assert!(code.iter().any(|l| l == "ldr r0, =_CUBE_VMESH"), "LOAD_MESH passes the image");
}

#[test]
fn three_d_builtins_are_uvm2_only() {
    let (_dir, assets) = cube_asset();
    for target in [Target::M6809, Target::Rp2350, Target::PiTrex] {
        let err = generate(SRC, &assets, &target).unwrap_err();
        assert!(err.contains("`LOAD_MESH()` is a 3D builtin (vpy3d); it is available on the uvm2 target only"), "{target:?}: {err}");
    }
}

#[test]
fn bad_arguments_are_errors_with_the_line() {
    let (_dir, assets) = cube_asset();
    let src = "\
small = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
short: i32 = [0, 0, 0]
def main():
    DRAW_MESH(\"cube\", small, 100)
    DRAW_MESH(\"ship\", short, 100)
    XF_ROT_Y(short)
def loop():
    pass
";
    let err = generate(src, &assets, &Target::Uvm2).unwrap_err();
    assert!(err.contains("line 4: `DRAW_MESH()` argument 2 must be a transform: `SMALL` has to be declared `i32`"), "{err}");
    assert!(err.contains("line 5: mesh \"ship\" not found"), "{err}");
    assert!(err.contains("line 5: `DRAW_MESH()` argument 2 must be a transform"), "{err}");
    assert!(err.contains("line 6: `XF_ROT_Y()` takes 2 arguments, got 1"), "{err}");
}

#[test]
fn effects_bones_and_cloth_name_their_layers() {
    let (_dir, assets) = cube_asset();
    let src = "\
pose: i32 = [0] * 12
n = 0
def main():
    LOAD_MESH(\"cube\")
    BONE_INIT(0)
    n = BONE_ADD(0, -1, 0, 100, 0, \"cube\") + BONE_ADD(0, 0, 0, -50, 0)
def loop():
    n = FX_SHATTER(\"cube\", pose, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    FX_STEP()
    SOFT_STEP()
";
    let m = {
        let tokens = vpy_parser::lex(src).expect("lex");
        let m = vpy_parser::parse_tokens(&tokens, "main.vpy").expect("parse");
        let mut modules = std::collections::HashMap::new();
        modules.insert("main".to_string(), m);
        vpy_unifier::unify_modules(modules, "main").expect("unify")
    };
    use vpy_codegen::arm::three_d::Group;
    assert_eq!(vpy_codegen::arm::three_d::groups(&m), vec![Group::Core, Group::Fx, Group::Bones, Group::Soft]);

    let asm = generate(src, &assets, &Target::Uvm2).unwrap();
    let code = instrs(&asm);
    // FX_SHATTER: 12 C arguments → r0-r3 and vpyx_args[0..7].
    let at = code.iter().position(|l| l == "bl vpyx_fx_shatter").unwrap();
    for k in 0..8 {
        assert!(code[..at].iter().any(|l| *l == format!("str r0, [r1, #{}]", k * 4)), "vpyx_args[{k}]");
    }
    // BONE_ADD without a mesh passes -1.
    assert!(code.iter().any(|l| l == "ldr r0, =-1"), "no-mesh marker");
}

#[test]
fn a_program_function_shadows_a_3d_builtin() {
    // examples/zaxxon_poc defines its own project(); names are case-insensitive.
    let src = "\
r = 0
def project(a, b):
    return a + b
def main():
    r = PROJECT(1, 2)
def loop():
    pass
";
    for target in [Target::M6809, Target::Uvm2] {
        let asm = generate(src, &[], &target).unwrap_or_else(|e| panic!("{target:?}: {e}"));
        assert!(!asm.contains("vpyx_project"), "{target:?}");
    }
}
