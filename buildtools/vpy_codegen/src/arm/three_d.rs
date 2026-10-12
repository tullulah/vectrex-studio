//! 3D builtins (uvm2): `.vmesh` meshes, `.vscene` scenes, transforms, the camera,
//! occluders and fog over the SDK's vpy3d, and the layers on top of it — effects
//! (vpyfx), skeletons (vpybone) and soft bodies (vpysoft) — the same C that C
//! games use. Each builtin belongs to a [`Group`]: vpy_cli compiles only the SDK
//! files of the groups a program uses.
//!
//! A transform is a global `i32` array of 12 elements — vpy3d's `vpy_xf`
//! (`m[9]` Q14 rotation, `t[3]` translation) has exactly that layout, so the
//! array's address is passed to C as a `vpy_xf *`:
//!
//! ```python
//! ship: i32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
//! XF_ROT_Y(ship, angle)                 # angles: 4096 per turn
//! DRAW_MESH("tie_cockpit", ship, 100)
//! ```
//!
//! Every builtin is a call into `vpy3d_bridge.c` (shipped inside vpy_cli and
//! compiled with the SDK's vpy3d.c into the image), whose functions take only
//! integers and pointers. The call follows the AAPCS: the first four arguments
//! in r0-r3, the rest in `vpyx_args` (a C array) — never on the stack — and SP
//! aligned to 8 bytes at the `bl`, whatever the expression evaluation pushed.
//! Meshes and scenes are named by string literal and become an index into the
//! bridge's mesh/scene slots, which vpy_cli sizes (`VPYX_MESHES`/`VPYX_SCENES`).
//!
//! The jukebox builtins ([`Group::Juke`]: MUSIC_TRACK, SFX_PCM, LISTENER…) use the
//! same calling path into `vpy_jukebox.c`, also shipped inside vpy_cli: recorded music
//! and effects off the SD card, out of the UVMC2's audio jack. They need no 3D.

use crate::{AssetInfo, AssetType};
use std::cell::RefCell;
use std::collections::BTreeMap;
use vpy_parser::{CallInfo, Expr, Item, Module};

/// How one VPy argument becomes C arguments.
#[derive(Clone, Copy, PartialEq)]
enum Arg {
    /// An integer expression.
    Int,
    /// A string: a literal, a variable or parameter that holds one, or a call that
    /// returns one (LABEL_NUM).
    Str,
    /// A `.vec` by name → its libvpy image (`_NAME_VEC`).
    Vector,
    /// A transform: a global `i32`/`u32` array of at least 12 elements.
    Xf,
    /// A global `i32`/`u32` array of at least this many elements, by address.
    Words(usize),
    /// A mesh: its name → its slot index, or an integer expression holding a slot
    /// (`MESH("name")`, passed around in variables and parameters).
    Mesh,
    /// An optional mesh by name → its slot index, -1 when left out.
    OptMesh,
    /// A mesh by name → its slot index AND its data.
    MeshData,
    /// A scene by name → its slot index.
    Scene,
    /// A scene by name → its slot index, its data and its mesh table.
    SceneData,
}

struct Builtin {
    name: &'static str,
    c_fn: &'static str,
    args: &'static [Arg],
    /// Trailing arguments that may be left out (C receives 0 for them, -1 for a mesh).
    optional: usize,
    group: Group,
}

/// The SDK layer a builtin needs (each one a C file vpy_cli compiles in).
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
pub enum Group {
    /// vpy3d.c: meshes, scenes, the camera.
    Core,
    /// vpyfx.c: sparks, bursts, shatters.
    Fx,
    /// vpybone.c + vpyik.c: skeletons.
    Bones,
    /// vpysoft.c: cloth and soft bodies.
    Soft,
    /// vpy_jukebox.c (in vpy_cli, not the SDK): music and effects off the SD card.
    Juke,
}

impl Group {
    /// The SDK's vpy-c sources it needs (vpy3d.c always).
    pub fn sources(self) -> &'static [&'static str] {
        match self {
            Group::Core => &["vpy3d.c"],
            Group::Fx => &["vpyfx.c"],
            Group::Bones => &["vpybone.c", "vpyik.c"],
            Group::Soft => &["vpysoft.c"],
            Group::Juke => &[],
        }
    }
    /// The define that compiles its part of the bridge.
    pub fn define(self) -> &'static str {
        match self {
            Group::Core => "VPYX_3D",
            Group::Fx => "VPYX_FX",
            Group::Bones => "VPYX_BONES",
            Group::Soft => "VPYX_SOFT",
            Group::Juke => "VPYX_JUKE",
        }
    }
    /// Does it sit on vpy3d (and so need the 3D bridge)?
    pub fn is_3d(self) -> bool {
        self != Group::Juke
    }
}

use Arg::*;
use Group::*;

const BUILTINS: &[Builtin] = &[
    // transforms (an i32 array of 12)
    Builtin { name: "XF_IDENTITY", c_fn: "vpyx_xf_identity", args: &[Xf], optional: 0, group: Core },
    Builtin { name: "XF_TRANSLATE", c_fn: "vpyx_xf_translate", args: &[Xf, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "XF_ROT_X", c_fn: "vpyx_xf_rot_x", args: &[Xf, Int], optional: 0, group: Core },
    Builtin { name: "XF_ROT_Y", c_fn: "vpyx_xf_rot_y", args: &[Xf, Int], optional: 0, group: Core },
    Builtin { name: "XF_ROT_Z", c_fn: "vpyx_xf_rot_z", args: &[Xf, Int], optional: 0, group: Core },
    Builtin { name: "XF_MUL", c_fn: "vpyx_xf_mul", args: &[Xf, Xf, Xf], optional: 0, group: Core },
    Builtin { name: "XF_POINT", c_fn: "vpyx_xf_point", args: &[Words(3), Xf, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "XF_TO_MODEL", c_fn: "vpyx_world_to_model", args: &[Words(3), Xf, Int, Int, Int], optional: 0, group: Core },
    // the camera
    Builtin { name: "CAMERA_LOOK_AT", c_fn: "vpyx_look_at", args: &[Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 3, group: Core },
    Builtin { name: "CAMERA_SET", c_fn: "vpyx_set_camera", args: &[Xf], optional: 0, group: Core },
    Builtin { name: "CAMERA_GET", c_fn: "vpyx_get_camera", args: &[Xf], optional: 0, group: Core },
    Builtin { name: "CAMERA_FOCAL", c_fn: "vpyx_set_focal", args: &[Int], optional: 0, group: Core },
    Builtin { name: "CAMERA_NEAR", c_fn: "vpyx_set_near", args: &[Int], optional: 0, group: Core },
    Builtin { name: "CAMERA_CLIP", c_fn: "vpyx_set_clip", args: &[Int, Int], optional: 1, group: Core },
    Builtin { name: "PROJECT", c_fn: "vpyx_project", args: &[Words(2), Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "PROJECT_CAM", c_fn: "vpyx_project_cam", args: &[Words(2), Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "SCREEN_SIZE", c_fn: "vpy3d_screen_size", args: &[Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "ATAN2_Q14", c_fn: "vpyx_atan2_q14", args: &[Int, Int], optional: 0, group: Core },
    // Q14 trig: 4096 per turn, -16384..16384
    Builtin { name: "SIN_Q14", c_fn: "vpyx_sin_q14", args: &[Int], optional: 0, group: Core },
    Builtin { name: "COS_Q14", c_fn: "vpyx_cos_q14", args: &[Int], optional: 0, group: Core },
    // meshes
    Builtin { name: "LOAD_MESH", c_fn: "vpyx_load_mesh", args: &[MeshData], optional: 0, group: Core },
    Builtin { name: "DRAW_MESH", c_fn: "vpyx_draw_mesh", args: &[Mesh, Xf, Int], optional: 0, group: Core },
    Builtin { name: "MESH", c_fn: "", args: &[Mesh], optional: 0, group: Core },
    Builtin { name: "MESH_OCCLUSION", c_fn: "vpy3d_set_mesh_occlusion", args: &[Int], optional: 0, group: Core },
    Builtin { name: "MESH_POOL_MARK", c_fn: "vpyx_pool_mark", args: &[], optional: 0, group: Core },
    Builtin { name: "MESH_POOL_RELEASE", c_fn: "vpyx_pool_release", args: &[], optional: 0, group: Core },
    // scenes
    Builtin { name: "LOAD_SCENE", c_fn: "vpyx_load_scene", args: &[SceneData], optional: 0, group: Core },
    Builtin { name: "DRAW_SCENE", c_fn: "vpyx_draw_scene", args: &[Scene, Int, Int, Int, Int, Int], optional: 1, group: Core },
    Builtin { name: "DRAW_SCENE_AT", c_fn: "vpyx_draw_scene_at", args: &[Scene, Xf, Int, Int, Int, Int, Int], optional: 1, group: Core },
    // lines, occluders, fog
    Builtin { name: "LINE_3D", c_fn: "vpyx_line_world", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "LINE_CAM", c_fn: "vpyx_line_cam", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "OCCL_RESET", c_fn: "vpyx_occl_reset", args: &[], optional: 0, group: Core },
    Builtin { name: "OCCL_LINE", c_fn: "vpyx_occl_line", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "OCCL_MESH", c_fn: "vpyx_occl_add_mesh", args: &[Mesh, Xf], optional: 0, group: Core },
    Builtin { name: "OCCL_ADD", c_fn: "vpyx_occl_add", args: &[Words(9), Int], optional: 0, group: Core },
    // a ray against a placed mesh; damage marks that turn with their object
    Builtin { name: "RAY_MESH", c_fn: "vpyx_ray_mesh", args: &[Words(7), Mesh, Xf, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "MARKS_CLEAR", c_fn: "vpyx_marks_clear", args: &[Int], optional: 0, group: Core },
    Builtin { name: "MARKS_ADD", c_fn: "vpyx_marks_add", args: &[Int, Xf, Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "MARKS_DRAW", c_fn: "vpyx_marks_draw", args: &[Int, Xf, Int, Int, Int], optional: 1, group: Core },
    Builtin { name: "FOG", c_fn: "vpyx_fog", args: &[Int, Int, Int, Int, Int, Int], optional: 0, group: Core },
    Builtin { name: "SCENERY_FOG", c_fn: "vpyx_set_scenery_fog", args: &[Int, Int], optional: 0, group: Core },
    // text in the world (libvpy's font)
    Builtin { name: "TEXT_BILLBOARD", c_fn: "vpyx_text_billboard", args: &[Str, Int, Int, Int, Int, Int, Int], optional: 1, group: Core },
    Builtin { name: "TEXT_3D", c_fn: "vpyx_text", args: &[Str, Xf, Int, Int, Int], optional: 1, group: Core },
    Builtin { name: "LABEL_NUM", c_fn: "vpyx_label_num", args: &[Str, Int], optional: 0, group: Core },
    Builtin { name: "VEC_3D", c_fn: "vpyx_draw_vec", args: &[Vector, Xf, Int, Int, Int], optional: 1, group: Core },
    // effects (vpyfx): pieces that fly, fall, bounce and fade
    Builtin { name: "FX_RESET", c_fn: "vpyfx_reset", args: &[], optional: 0, group: Fx },
    Builtin { name: "FX_SEED", c_fn: "vpyfx_seed", args: &[Int], optional: 0, group: Fx },
    Builtin { name: "FX_RATE", c_fn: "vpyfx_set_rate", args: &[Int], optional: 0, group: Fx },
    Builtin { name: "FX_GRAVITY", c_fn: "vpyfx_set_gravity", args: &[Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_FLOOR", c_fn: "vpyfx_set_floor", args: &[Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_BUDGET", c_fn: "vpyfx_set_budget", args: &[Int], optional: 0, group: Fx },
    Builtin { name: "FX_SPARK", c_fn: "vpyx_fx_spark", args: &[Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_BURST", c_fn: "vpyx_fx_burst", args: &[Int, Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_STICK", c_fn: "vpyx_fx_stick", args: &[Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_SHATTER", c_fn: "vpyx_fx_shatter", args: &[Mesh, Xf, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_DISINTEGRATE", c_fn: "vpyx_fx_disintegrate", args: &[Mesh, Xf, Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_ASSEMBLE", c_fn: "vpyx_fx_assemble", args: &[Mesh, Xf, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_ASSEMBLED", c_fn: "vpyfx_assembled", args: &[Int], optional: 0, group: Fx },
    Builtin { name: "FX_RELEASE", c_fn: "vpyfx_release", args: &[Int], optional: 0, group: Fx },
    Builtin { name: "FX_RING", c_fn: "vpyx_fx_ring", args: &[Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_LINE", c_fn: "vpyx_fx_line", args: &[Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Fx },
    Builtin { name: "FX_STEP", c_fn: "vpyfx_step", args: &[], optional: 0, group: Fx },
    Builtin { name: "FX_DRAW", c_fn: "vpyfx_draw", args: &[Int], optional: 1, group: Fx },
    Builtin { name: "FX_DRAW2D", c_fn: "vpyfx_draw2d", args: &[], optional: 0, group: Fx },
    // skeletons (vpybone): bones with a mesh each, posed by rotations or IK
    Builtin { name: "BONE_INIT", c_fn: "vpyx_bone_init", args: &[Int], optional: 0, group: Bones },
    Builtin { name: "BONE_ADD", c_fn: "vpyx_bone_add", args: &[Int, Int, Int, Int, Int, OptMesh], optional: 1, group: Bones },
    Builtin { name: "BONE_ROT", c_fn: "vpyx_bone_rot", args: &[Int, Int, Int, Int, Int, Int], optional: 0, group: Bones },
    Builtin { name: "BONE_ROT_MUL", c_fn: "vpyx_bone_rot_mul", args: &[Int, Int, Int, Int, Int, Int], optional: 0, group: Bones },
    Builtin { name: "BONE_POSE", c_fn: "vpyx_bone_pose", args: &[Int, Int, Int, Int], optional: 0, group: Bones },
    Builtin { name: "BONE_XF", c_fn: "vpyx_bone_xf", args: &[Xf, Int, Int], optional: 0, group: Bones },
    Builtin { name: "BONE_POS", c_fn: "vpyx_bone_pos", args: &[Words(3), Int, Int], optional: 0, group: Bones },
    Builtin { name: "BONE_DRAW", c_fn: "vpyx_bone_draw", args: &[Int, Int, Int], optional: 1, group: Bones },
    Builtin { name: "BONE_IK", c_fn: "vpyx_bone_ik", args: &[Int, Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Bones },
    // soft bodies and cloth (vpysoft)
    Builtin { name: "SOFT_RESET", c_fn: "vpysoft_reset", args: &[], optional: 0, group: Soft },
    Builtin { name: "SOFT_RATE", c_fn: "vpysoft_set_rate", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_GRAVITY", c_fn: "vpysoft_set_gravity", args: &[Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_FLOOR", c_fn: "vpysoft_set_floor", args: &[Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_ITERATIONS", c_fn: "vpysoft_set_iterations", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_DAMPING", c_fn: "vpysoft_set_damping", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_BUDGET", c_fn: "vpysoft_set_budget", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_CLOTH", c_fn: "vpyx_soft_cloth", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_BLOB", c_fn: "vpyx_soft_blob", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_MESH", c_fn: "vpyx_soft_mesh", args: &[Mesh, Int, Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_FREE", c_fn: "vpysoft_free", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_POINTS", c_fn: "vpysoft_points", args: &[Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_POINT", c_fn: "vpyx_soft_point", args: &[Words(3), Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_PIN", c_fn: "vpyx_soft_pin", args: &[Int, Int, Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_UNPIN", c_fn: "vpysoft_unpin", args: &[Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_PUSH", c_fn: "vpysoft_push", args: &[Int, Int, Int, Int], optional: 0, group: Soft },
    Builtin { name: "SOFT_STEP", c_fn: "vpysoft_step", args: &[], optional: 0, group: Soft },
    Builtin { name: "SOFT_DRAW", c_fn: "vpysoft_draw", args: &[Int, Int, Int], optional: 1, group: Soft },
    // the jukebox (vpy_jukebox.c): recorded music and effects off the SD card, out of the jack
    Builtin { name: "JUKEBOX_DIR", c_fn: "vpyj_dir", args: &[Str], optional: 0, group: Juke },
    Builtin { name: "JUKEBOX_MODE", c_fn: "vpyj_mode", args: &[Int], optional: 0, group: Juke },
    Builtin { name: "JUKEBOX_LIVE", c_fn: "jukebox_live", args: &[], optional: 0, group: Juke },
    Builtin { name: "JUKEBOX_PROGRESS", c_fn: "jukebox_boot_progress", args: &[], optional: 0, group: Juke },
    Builtin { name: "JUKEBOX_REPORT", c_fn: "jukebox_report", args: &[], optional: 0, group: Juke },
    Builtin { name: "MUSIC_TRACK", c_fn: "jukebox_play", args: &[Str], optional: 0, group: Juke },
    Builtin { name: "SFX_PCM", c_fn: "vpyj_sfx", args: &[Int, Int, Int, Int], optional: 2, group: Juke },
    Builtin { name: "SFX_PCM_AT", c_fn: "vpyj_sfx_at", args: &[Int, Int, Int, Int, Int, Int, Int], optional: 0, group: Juke },
    Builtin { name: "SFX_PCM_MOVE", c_fn: "jukebox_voice_at", args: &[Int, Int, Int, Int], optional: 0, group: Juke },
    Builtin { name: "SFX_PCM_STOP", c_fn: "jukebox_sfx_stop", args: &[Int], optional: 0, group: Juke },
    Builtin { name: "SFX_PCM_BUSY", c_fn: "jukebox_sfx_busy", args: &[Int], optional: 0, group: Juke },
    Builtin { name: "LISTENER", c_fn: "vpyj_listener", args: &[Int, Int, Int, Int, Int], optional: 0, group: Juke },
];

fn find(name: &str) -> Option<&'static Builtin> {
    BUILTINS.iter().find(|b| b.name.eq_ignore_ascii_case(name))
}

/// The 3D builtin a call in `module` names, unless the program defines a function
/// of that name (names are case-insensitive): the program's own function wins.
fn find_in(module: &Module, name: &str) -> Option<&'static Builtin> {
    let b = find(name)?;
    let defined = module.items.iter().any(|i| matches!(i, Item::Function(f) if f.name.eq_ignore_ascii_case(name)));
    (!defined).then_some(b)
}

/// Is `name` one of the 3D builtins?
pub fn is_3d_builtin(name: &str) -> bool {
    find(name).is_some()
}

/// Every builtin's C function and how many C arguments it receives (a mesh with its data
/// is two, a scene with its data three): r0-r3 carry the first four, `vpyx_args[]` the rest.
pub fn c_calls() -> impl Iterator<Item = (&'static str, &'static str, usize)> {
    BUILTINS.iter().map(|b| {
        let n = b.args.iter().map(|a| match a { MeshData => 2, SceneData => 3, _ => 1 }).sum();
        (b.name, b.c_fn, n)
    })
}

/// Every 3D builtin's name, for the builtin catalog.
pub fn names() -> impl Iterator<Item = &'static str> {
    BUILTINS.iter().map(|b| b.name)
}

/// The layers `module` uses, Core first when any 3D one is used.
pub fn groups(module: &Module) -> Vec<Group> {
    let mut set = std::collections::BTreeSet::new();
    crate::m6809::ast_walk::for_each_call(module, |c| {
        if let Some(b) = find_in(module, &c.name) {
            if b.group.is_3d() {
                set.insert(Core);
            }
            set.insert(b.group);
        }
    });
    set.into_iter().collect()
}

/// The meshes and scenes a program names in 3D builtins, in slot order.
#[derive(Debug, Default, Clone, PartialEq)]
pub struct Usage {
    pub meshes: Vec<String>,
    pub scenes: Vec<String>,
}

thread_local! {
    static SLOTS: RefCell<Usage> = RefCell::new(Usage::default());
}

/// Does `module` call any 3D builtin (one on vpy3d)?
pub fn uses_3d(module: &Module) -> bool {
    groups(module).iter().any(|g| g.is_3d())
}

/// Does `module` call any jukebox builtin?
pub fn uses_jukebox(module: &Module) -> bool {
    groups(module).contains(&Juke)
}

/// The meshes and scenes `module` names, each once, sorted (the slot numbers).
pub fn usage(module: &Module) -> Usage {
    let mut meshes = std::collections::BTreeSet::new();
    let mut scenes = std::collections::BTreeSet::new();
    crate::m6809::ast_walk::for_each_call(module, |c| {
        let Some(b) = find_in(module, &c.name) else { return };
        for (arg, e) in b.args.iter().zip(&c.args) {
            if let Expr::StringLit(s) = e {
                match arg {
                    Mesh | MeshData | OptMesh => {
                        meshes.insert(s.clone());
                    }
                    Scene | SceneData => {
                        scenes.insert(s.clone());
                    }
                    _ => {}
                }
            }
        }
    });
    Usage { meshes: meshes.into_iter().collect(), scenes: scenes.into_iter().collect() }
}

/// Global arrays: UPPERCASE name → (element bytes, length).
fn global_arrays(module: &Module) -> BTreeMap<String, (usize, usize)> {
    module
        .items
        .iter()
        .filter_map(|item| match item {
            Item::GlobalLet { name, value: Expr::List(v), type_annotation, .. }
            | Item::Const { name, value: Expr::List(v), type_annotation, .. } => Some((
                name.to_uppercase(),
                (crate::m6809::context::VarSize::from_annotation(type_annotation).bytes, v.len()),
            )),
            _ => None,
        })
        .collect()
}

/// Check every 3D call of `module` for `target`: the target has the 3D layer,
/// the argument count, names that are string literals of existing assets, and
/// transforms/word arrays that are global i32 arrays long enough.
pub fn check(module: &Module, assets: &[AssetInfo], target: &str) -> Result<(), String> {
    let arrays = global_arrays(module);
    let count = |t: AssetType, n: &str| assets.iter().filter(|a| a.asset_type == t && a.name == n).count();
    let mut errors = Vec::new();
    crate::m6809::ast_walk::for_each_call_in_items(module, |item, c: &CallInfo| {
        let start = errors.len();
        #[allow(clippy::redundant_closure_call)]
        (|| {
        let Some(b) = find_in(module, &c.name) else { return };
        let line = c.source_line;
        if target != "uvm2" {
            let what = if b.group == Juke { "a jukebox builtin (the UVMC2's audio jack)" } else { "a 3D builtin (vpy3d)" };
            errors.push(format!(
                "line {line}: `{}()` is {what}; it is available on the uvm2 target only, not on {target}",
                b.name
            ));
            return;
        }
        let (min, max) = (b.args.len() - b.optional, b.args.len());
        if c.args.len() < min || c.args.len() > max {
            let want = if min == max { format!("{max}") } else { format!("{min} to {max}") };
            errors.push(format!("line {line}: `{}()` takes {want} arguments, got {}", b.name, c.args.len()));
            return;
        }
        for (i, (arg, e)) in b.args.iter().zip(&c.args).enumerate() {
            let n = i + 1;
            match arg {
                Int => {
                    if matches!(e, Expr::StringLit(_)) {
                        errors.push(format!("line {line}: `{}()` argument {n} is a number, not a string", b.name));
                    }
                }
                Str => {
                    if !matches!(e, Expr::StringLit(_) | Expr::Ident(_) | Expr::Call(_) | Expr::Index { .. }) {
                        errors.push(format!(
                            "line {line}: `{}()` argument {n} must be a string: a literal, or a variable or parameter holding one",
                            b.name
                        ));
                    }
                }
                Vector => match e {
                    Expr::StringLit(s) if count(AssetType::Vector, s) >= 1 => {}
                    Expr::StringLit(s) => errors.push(format!(
                        "line {line}: vector \"{s}\" not found: there is no {s}.vec in assets/vectors/"
                    )),
                    _ => errors.push(format!(
                        "line {line}: `{}()` argument {n} must be the vector's name as a string literal",
                        b.name
                    )),
                },
                Mesh | OptMesh if !matches!(e, Expr::StringLit(_)) && b.name != "MESH" => {
                    // a slot held in a variable (from MESH("name"))
                }
                Mesh | MeshData | OptMesh | Scene | SceneData => {
                    let (kind, t, folder) = if matches!(arg, Mesh | MeshData | OptMesh) {
                        ("mesh", AssetType::Mesh, "assets/meshes/ (any folder)")
                    } else {
                        ("scene", AssetType::Scene, "assets/scenes/")
                    };
                    match e {
                        Expr::StringLit(s) if count(t.clone(), s) > 1 => errors.push(format!(
                            "line {line}: {kind} \"{s}\" is in more than one folder of {folder}: names must be unique"
                        )),
                        Expr::StringLit(s) if count(t.clone(), s) == 1 => {}
                        Expr::StringLit(s) => errors.push(format!(
                            "line {line}: {kind} \"{s}\" not found: there is no {s}.{} in {folder}",
                            if kind == "mesh" { "vmesh" } else { "vscene" }
                        )),
                        _ => errors.push(format!(
                            "line {line}: `{}()` argument {n} must be the {kind}'s name as a string literal, e.g. \"ship\"",
                            b.name
                        )),
                    }
                }
                Xf | Words(_) => {
                    let need = if let Words(w) = arg { *w } else { 12 };
                    let what = if *arg == Xf { "a transform" } else { "an i32 array" };
                    let Expr::Ident(id) = e else {
                        errors.push(format!(
                            "line {line}: `{}()` argument {n} must be {what}: the name of a global `i32` array \
                             of {need} or more elements",
                            b.name
                        ));
                        continue;
                    };
                    // A parameter carries an array address the caller checked.
                    let Some(&(bytes, len)) = arrays.get(&id.name.to_uppercase()) else { continue };
                    if bytes != 4 || len < need {
                        errors.push(format!(
                            "line {line}: `{}()` argument {n} must be {what}: `{}` has to be declared `i32` with \
                             {need} or more elements (e.g. `{}: i32 = [0, 0, …]`)",
                            b.name, id.name, id.name.to_lowercase()
                        ));
                    }
                }
            }
        }
    })();
        crate::origins::locate_new(&mut errors, start, item);
    });
    if errors.is_empty() { Ok(()) } else { Err(errors.join("\n")) }
}

/// Record the slots of `module`'s meshes and scenes for this compile.
pub fn setup(module: &Module) {
    SLOTS.with(|s| *s.borrow_mut() = usage(module));
}

fn slot(kind: Arg, name: &str) -> usize {
    SLOTS.with(|s| {
        let s = s.borrow();
        let list = if matches!(kind, Mesh | MeshData | OptMesh) { &s.meshes } else { &s.scenes };
        list.iter().position(|n| n == name).unwrap_or(0)
    })
}

/// Assembly symbol of an asset's data.
pub fn mesh_symbol(name: &str) -> String {
    format!("_{}_VMESH", sym(name))
}
fn scene_symbol(name: &str) -> String {
    format!("_{}_VSCENE", sym(name))
}
fn sym(name: &str) -> String {
    name.to_uppercase().replace(['-', ' ', '.'], "_")
}

/// One argument handed to C.
enum CArg<'a> {
    Expr(&'a Expr),
    Imm(i64),
    Sym(String),
}

/// A builtin call lowered to its C function and arguments, for any backend.
pub enum Lowered<'a> {
    /// `MESH("name")`: no call, the slot number itself.
    Slot(i64),
    /// A call of `c_fn` with these arguments (r0-r3, then `vpyx_args[]`).
    Call(&'static str, Vec<CPart<'a>>),
}

/// One C argument of a lowered builtin call.
pub enum CPart<'a> {
    Expr(&'a Expr),
    Imm(i64),
    /// An asset's data, by name: the backend names its symbol.
    Data(AssetData, String),
}

/// Which data of an asset an argument passes.
#[derive(Clone, Copy, PartialEq, Debug)]
pub enum AssetData {
    /// a `.vmesh` image
    Mesh,
    /// a `.vscene` image
    Scene,
    /// the table of the mesh images a `.vscene` places
    SceneMeshes,
    /// a `.vec` image (libvpy's position-independent one)
    Vec,
}

/// The builtin `info` calls, lowered (None: not a builtin of this table, or the
/// program defines a function of that name).
pub fn lower_call(info: &CallInfo) -> Option<Result<Lowered<'_>, String>> {
    if crate::known_functions::is_defined(&info.name) {
        return None; // the program's own function of that name
    }
    let b = find(&info.name)?;
    if b.name == "MESH" {
        // the slot itself, as a number
        let Some(Expr::StringLit(s)) = info.args.first() else {
            return Some(Err(format!("line {}: `MESH()` needs the mesh's name as a string literal", info.source_line)));
        };
        return Some(Ok(Lowered::Slot(slot(Mesh, s) as i64)));
    }
    let mut c_args: Vec<CPart> = Vec::new();
    for (i, arg) in b.args.iter().enumerate() {
        let Some(e) = info.args.get(i) else {
            c_args.push(CPart::Imm(if *arg == OptMesh { -1 } else { 0 }));
            continue;
        };
        match (arg, e) {
            (Mesh | OptMesh | Scene, Expr::StringLit(s)) => c_args.push(CPart::Imm(slot(*arg, s) as i64)),
            (Vector, Expr::StringLit(s)) => c_args.push(CPart::Data(AssetData::Vec, s.clone())),
            (MeshData, Expr::StringLit(s)) => {
                c_args.push(CPart::Imm(slot(*arg, s) as i64));
                c_args.push(CPart::Data(AssetData::Mesh, s.clone()));
            }
            (SceneData, Expr::StringLit(s)) => {
                c_args.push(CPart::Imm(slot(*arg, s) as i64));
                c_args.push(CPart::Data(AssetData::Scene, s.clone()));
                c_args.push(CPart::Data(AssetData::SceneMeshes, s.clone()));
            }
            (Mesh | OptMesh, _) => c_args.push(CPart::Expr(e)),
            (Scene | MeshData | SceneData | Vector, _) => {
                return Some(Err(format!(
                    "line {}: `{}()` needs the asset's name as a string literal",
                    info.source_line, b.name
                )))
            }
            _ => c_args.push(CPart::Expr(e)),
        }
    }
    Some(Ok(Lowered::Call(b.c_fn, c_args)))
}

/// Code for a 3D builtin call (None: `info` is not one). Result in r0.
pub fn emit_call(
    info: &CallInfo,
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Option<Result<String, String>> {
    let (c_fn, parts) = match lower_call(info)? {
        Err(e) => return Some(Err(e)),
        Ok(Lowered::Slot(n)) => return Some(Ok(format!("    ldr     r0, ={n}\n"))),
        Ok(Lowered::Call(f, parts)) => (f, parts),
    };
    let c_args: Vec<CArg> = parts
        .into_iter()
        .map(|p| match p {
            CPart::Expr(e) => CArg::Expr(e),
            CPart::Imm(n) => CArg::Imm(n),
            CPart::Data(AssetData::Vec, s) => CArg::Sym(format!("_{}_VEC", sym(&s))),
            CPart::Data(AssetData::Mesh, s) => CArg::Sym(mesh_symbol(&s)),
            CPart::Data(AssetData::Scene, s) => CArg::Sym(scene_symbol(&s)),
            CPart::Data(AssetData::SceneMeshes, s) => CArg::Sym(format!("{}_MESHES", scene_symbol(&s))),
        })
        .collect();
    Some(emit_c_call(c_fn, &c_args, var_addrs))
}

/// Evaluate `args`, pass them per the AAPCS (r0-r3, then `vpyx_args[]`) and call
/// `c_fn` with SP 8-byte aligned. Result in r0.
fn emit_c_call(
    c_fn: &str,
    args: &[CArg],
    var_addrs: &std::collections::HashMap<String, u32>,
) -> Result<String, String> {
    use super::expressions::leaf_into;
    let mut s = format!("    @ {c_fn} (C)\n");
    let mut codes = Vec::new();
    for a in args {
        codes.push(match a {
            // (a string literal becomes the address of its NUL-terminated text)
            CArg::Expr(e) => super::expressions::emit_arg(e, var_addrs)?,
            CArg::Imm(n) if (0..=255).contains(n) => format!("    mov     r0, #{n}\n"),
            CArg::Imm(n) => format!("    ldr     r0, ={n}\n"),
            CArg::Sym(sym) => format!("    ldr     r0, ={sym}\n"),
        });
    }
    // A leaf (a constant, a local, a global) is loaded straight where it goes, after the
    // others are evaluated -- not a push and a pop each. A global only when nothing else
    // makes a call (which could change it).
    let calls = codes.iter().any(|c| leaf_into(c, 0, false).is_none() && c.contains("bl"));
    let leaf: Vec<bool> = codes.iter().map(|c| leaf_into(c, 0, !calls).is_some()).collect();
    for (c, l) in codes.iter().zip(&leaf) {
        if !l {
            s.push_str(c);
            s.push_str("    push    {r0}\n");
        }
    }
    // The extra arguments into vpyx_args[] (the others on the stack in reverse), then r3..r0.
    if args.len() > 4 {
        // (r1 keeps the table's address throughout: a leaf only touches r0)
        s.push_str("    ldr     r1, =vpyx_args\n");
        for i in (4..args.len()).rev() {
            if !leaf[i] {
                s.push_str("    pop     {r0}\n");
                s.push_str(&format!("    str     r0, [r1, #{}]\n", (i - 4) * 4));
            }
        }
        for i in 4..args.len() {
            if leaf[i] {
                s.push_str(&leaf_into(&codes[i], 0, !calls).unwrap());
                s.push_str(&format!("    str     r0, [r1, #{}]\n", (i - 4) * 4));
            }
        }
    }
    for i in (0..args.len().min(4)).rev() {
        if !leaf[i] {
            s.push_str(&format!("    pop     {{r{i}}}\n"));
        }
    }
    for i in 0..args.len().min(4) {
        if leaf[i] {
            s.push_str(&leaf_into(&codes[i], i, !calls).unwrap());
        }
    }
    // AAPCS: SP 8-byte aligned at the call, whatever the evaluation pushed: through
    // vpyx_call (the C side's trampoline: it aligns SP, calls r12, puts SP back), one
    // `ldr`+`bl` here instead of seven instructions at every call.
    s.push_str(&format!("    ldr     r12, ={c_fn}\n"));
    s.push_str("    bl      vpyx_call\n");
    Ok(s)
}

/// The data of the meshes and scenes the program names: each `.vmesh` image as
/// `_NAME_VMESH`, each `.vscene` image as `_NAME_VSCENE` with its mesh table
/// `_NAME_VSCENE_MESHES` (the images of the meshes it places, in its order).
pub fn emit_data(assets: &[AssetInfo]) -> Result<String, String> {
    let used = SLOTS.with(|s| s.borrow().clone());
    if used.meshes.is_empty() && used.scenes.is_empty() {
        return Ok(String::new());
    }
    let path_of = |t: AssetType, n: &str| {
        assets.iter().find(|a| a.asset_type == t && a.name == n).map(|a| std::path::PathBuf::from(&a.path))
    };
    let mut s = String::from("@ --- 3D assets (vpy3d images) ---\n.section .rodata.vpy3d, \"a\"\n");
    let mut emitted = std::collections::BTreeSet::new();
    let mut meshes: Vec<String> = used.meshes.clone();
    let mut scenes = Vec::new();
    for name in &used.scenes {
        let path = path_of(AssetType::Scene, name).ok_or_else(|| format!("scene \"{name}\" not found"))?;
        let c = crate::vsceneres::compile_vscene_file_to_bytes(&path)
            .map_err(|e| format!("scene \"{name}\" ({}): {e}", path.display()))?;
        meshes.extend(c.meshes.iter().cloned());
        scenes.push((name.clone(), c));
    }
    for name in &meshes {
        if !emitted.insert(name.clone()) {
            continue;
        }
        let path = path_of(AssetType::Mesh, name).ok_or_else(|| format!("mesh \"{name}\" not found"))?;
        let bytes = crate::vmeshres::compile_vmesh_file_to_bytes(&path)
            .map_err(|e| format!("mesh \"{name}\" ({}): {e}", path.display()))?;
        s.push_str(&format!(".balign 4\n{}:\n", mesh_symbol(name)));
        s.push_str(&bytes_directives(&bytes));
    }
    for (name, c) in &scenes {
        s.push_str(&format!(".balign 4\n{}:\n", scene_symbol(name)));
        s.push_str(&bytes_directives(&c.bytes));
        s.push_str(&format!(".balign 4\n{}_MESHES:\n", scene_symbol(name)));
        for m in &c.meshes {
            s.push_str(&format!("    .word   {}\n", mesh_symbol(m)));
        }
    }
    s.push_str(".text\n\n");
    Ok(s)
}

fn bytes_directives(bytes: &[u8]) -> String {
    let mut s = String::new();
    for chunk in bytes.chunks(16) {
        let list: Vec<String> = chunk.iter().map(|b| format!("0x{b:02X}")).collect();
        s.push_str(&format!("    .byte   {}\n", list.join(",")));
    }
    s
}
