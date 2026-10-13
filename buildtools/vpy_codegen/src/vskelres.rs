//! `.vskel` — a 3D skeleton (bones, joints, sockets and the characters that share it;
//! docs/ASSETS.md), made into constant tables a game builds and turns its skeletons from: the
//! same tables as a C header (`vpy_cli compile-asset x.vskel --format c`) and as a VPy module
//! (`import x` finds `assets/skeletons/**/x.vskel`).
//!
//! | name | what |
//! |---|---|
//! | `N_JOINTS`, `JOINT_<j>` | the joints, in order |
//! | `N_BONES`, `BONE_<b>` | every bone: the shared ones, then the variants' own |
//! | `N_VARIANTS`, `VARIANT_<v>`, `T_VARIANTS[N_VARIANTS][2]` | a variant's scale (Q8) and bone count |
//! | `T_BONES[N_BONES][5]` | parent (-1: the root), offset x y z as modelled, turn list |
//! | `N_ROTS`, `T_ROTS[N_ROTS][2]` | a turn list: first row in T_TURNS, how many |
//! | `N_TURNS`, `T_TURNS[N_TURNS][5]` | axis (0 x, 1 y, 2 z), joint (-1: none), mul, div, add |
//! | `N_MESHES`, `MESH_<m>`, `T_BONE_MESHES[N_VARIANTS][N_BONES]` | each bone's mesh per variant (-1: none) |
//! | `N_VARIANT_BONES`, `T_VARIANT_BONES[..][6]` | variant, bone, offset x y z, turn list: where a variant differs from T_BONES |
//! | `N_SOCKETS`, `SOCKET_<s>`, `T_VARIANT_SOCKETS[N_VARIANTS][N_SOCKETS]` | each variant's socket (row of T_SOCKETS, -1: none) |
//! | `T_SOCKETS[..][7]` | bone, from x y z, to x y z (in the bone's frame, as modelled) |
//! | `T_MESHES[N_MESHES]` | VPy only: each mesh's `MESH("name")` slot |
//!
//! Variants are numbered in the alphabetical order of their names, meshes too; bones in the
//! file's order (the variants' own after the shared ones, each at the same number in every
//! variant that adds it); sockets in the order first met (the skeleton's, then each
//! variant's). A file without variants has one, `default`. Every table is there: one with
//! nothing in it holds a row that is never read (`N_VARIANT_BONES` 0: one row of -1s; no
//! sockets: one column of -1). Offsets are as modelled: a
//! program scales them by the variant's scale (`offset * scale / 256`, truncating), and
//! places the meshes and sockets with that same scale.

use crate::vclipres::{find_file, skeletons_dir};
use anyhow::{anyhow, bail, Context, Result};
use serde_json::{Map, Value};
use std::collections::HashMap;
use std::path::Path;

#[derive(Debug, Clone, PartialEq)]
pub struct Turn {
    pub axis: i64,
    pub joint: Option<usize>,
    pub mul: i64,
    pub div: i64,
    pub add: i64,
}

#[derive(Debug, Clone)]
pub struct Bone {
    pub name: String,
    pub parent: Option<usize>,
    pub offset: [i64; 3],
    pub mesh: Option<String>,
    pub rotate: Vec<Turn>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Socket {
    pub name: String,
    pub bone: usize,
    pub from: [i64; 3],
    pub to: [i64; 3],
}

/// A character, resolved: every bone it has (shared ones first), as modelled.
#[derive(Debug, Clone)]
pub struct Variant {
    pub name: String,
    pub scale: i64,
    pub bones: Vec<Bone>,
    pub sockets: Vec<Socket>,
}

#[derive(Debug, Clone)]
pub struct SkelLib {
    pub joints: Vec<String>,
    /// the shared bones, as the skeleton defines them
    pub shared: Vec<Bone>,
    pub variants: Vec<Variant>,
}

fn valid_name(n: &str) -> bool {
    let mut c = n.chars();
    matches!(c.next(), Some(ch) if ch.is_ascii_alphabetic() || ch == '_') && c.all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn obj<'a>(v: &'a Value, what: &str) -> Result<&'a Map<String, Value>> {
    v.as_object().ok_or_else(|| anyhow!("{what} must be an object"))
}

fn vec3(v: Option<&Value>, what: &str) -> Result<[i64; 3]> {
    let a = v.and_then(|x| x.as_array()).filter(|a| a.len() == 3);
    let p: Option<Vec<i64>> = a.map(|a| a.iter().map(|x| x.as_i64()).collect::<Option<Vec<_>>>()).flatten();
    p.map(|p| [p[0], p[1], p[2]]).ok_or_else(|| anyhow!("{what} must be three whole numbers"))
}

fn mesh_of(v: &Value, what: &str) -> Result<Option<String>> {
    match v {
        Value::Null => Ok(None),
        Value::String(s) => Ok(Some(s.clone())),
        _ => bail!("{what} must be a name or null"),
    }
}

fn turns(v: &Value, joints: &[String], where_: &str) -> Result<Vec<Turn>> {
    let list = v.as_array().ok_or_else(|| anyhow!("{where_}: rotate must be a list"))?;
    let mut out = Vec::new();
    for (k, t) in list.iter().enumerate() {
        let t = obj(t, &format!("{where_}: turn {k}"))?;
        let axis = match t.get("axis").and_then(|a| a.as_str()) {
            Some("x") => 0,
            Some("y") => 1,
            Some("z") => 2,
            _ => bail!("{where_}: turn {k} needs an axis x, y or z"),
        };
        let joint = match t.get("joint") {
            None => None,
            Some(j) => {
                let n = j.as_str().unwrap_or("");
                Some(joints.iter().position(|x| x == n).ok_or_else(|| anyhow!("{where_}: turn {k}: no joint \"{n}\""))?)
            }
        };
        let num = |f: &str, d: i64| -> Result<i64> {
            match t.get(f) {
                None => Ok(d),
                Some(x) => x.as_i64().ok_or_else(|| anyhow!("{where_}: turn {k}: {f} must be a whole number")),
            }
        };
        let (mul, div, add) = (num("mul", 1)?, num("div", 1)?, num("add", 0)?);
        if div == 0 {
            bail!("{where_}: turn {k}: div cannot be 0");
        }
        if joint.is_none() && add == 0 {
            bail!("{where_}: turn {k} has neither a joint nor an add: it does nothing");
        }
        out.push(Turn { axis, joint, mul, div, add });
    }
    Ok(out)
}

/// Bones of a list, added to `known` (names → index).
fn bones(list: &[Value], known: &mut Vec<Bone>, joints: &[String], variant: Option<&str>) -> Result<()> {
    let where_ = variant.map(|v| format!("variant \"{v}\": ")).unwrap_or_default();
    for (k, b) in list.iter().enumerate() {
        let name = b.get("name").and_then(|n| n.as_str()).filter(|n| valid_name(n))
            .ok_or_else(|| anyhow!("{where_}bone {k}: needs a name (letters, digits, _)"))?;
        if known.iter().any(|x| x.name == name) {
            bail!("{where_}bone \"{name}\" is defined twice");
        }
        let parent = match b.get("parent") {
            Some(Value::Null) | None if variant.is_none() && known.is_empty() => None,
            Some(Value::Null) | None => bail!("{where_}bone \"{name}\": only the first bone may be the root (parent null)"),
            Some(p) => {
                let p = p.as_str().unwrap_or("");
                Some(known.iter().position(|x| x.name == p)
                    .ok_or_else(|| anyhow!("{where_}bone \"{name}\": its parent \"{p}\" must be a bone listed before it"))?)
            }
        };
        let offset = vec3(b.get("offset"), &format!("{where_}bone \"{name}\": offset"))?;
        let mesh = mesh_of(b.get("mesh").unwrap_or(&Value::Null), &format!("{where_}bone \"{name}\": mesh"))?;
        let rotate = match b.get("rotate") {
            None => Vec::new(),
            Some(r) => turns(r, joints, &format!("{where_}bone \"{name}\""))?,
        };
        known.push(Bone { name: name.to_string(), parent, offset, mesh, rotate });
    }
    Ok(())
}

fn sockets(v: &Value, known: &[Bone], variant: Option<&str>) -> Result<Vec<Socket>> {
    let where_ = variant.map(|v| format!("variant \"{v}\": ")).unwrap_or_default();
    let list = v.as_array().ok_or_else(|| anyhow!("{where_}sockets must be a list"))?;
    let mut out: Vec<Socket> = Vec::new();
    for (k, s) in list.iter().enumerate() {
        let name = s.get("name").and_then(|n| n.as_str()).filter(|n| valid_name(n))
            .ok_or_else(|| anyhow!("{where_}socket {k}: needs a name (letters, digits, _)"))?;
        if out.iter().any(|x| x.name == name) {
            bail!("{where_}socket \"{name}\" is defined twice");
        }
        let b = s.get("bone").and_then(|b| b.as_str()).unwrap_or("");
        let bone = known.iter().position(|x| x.name == b).ok_or_else(|| anyhow!("{where_}socket \"{name}\": no bone \"{b}\""))?;
        let what = format!("{where_}socket \"{name}\": from and to");
        out.push(Socket { name: name.to_string(), bone, from: vec3(s.get("from"), &what)?, to: vec3(s.get("to"), &what)? });
    }
    Ok(out)
}

/// Check a `.vskel` and resolve every variant. The errors are the editor's
/// (ide/frontend/src/components/anim3d/animModel.ts validateVskel). `mesh_exists`, when
/// given, says whether a `.vmesh` of that name is in the project.
pub fn compile_vskel(v: &Value, mesh_exists: Option<&dyn Fn(&str) -> bool>) -> Result<SkelLib> {
    let root = obj(v, "a .vskel")?;
    if root.get("version").and_then(|x| x.as_i64()) != Some(1) {
        bail!("version must be 1");
    }
    if !root.get("angle_unit").and_then(|x| x.as_i64()).is_some_and(|u| u > 0) {
        bail!("angle_unit must be a whole number above 0 (4096 is libvpy's turn)");
    }
    let mut joints: Vec<String> = Vec::new();
    for (k, j) in root.get("joints").and_then(|j| j.as_array()).ok_or_else(|| anyhow!("joints must be a list"))?.iter().enumerate() {
        let n = j.get("name").and_then(|n| n.as_str()).filter(|n| valid_name(n))
            .ok_or_else(|| anyhow!("joint {k}: needs a name (letters, digits, _)"))?;
        if joints.iter().any(|x| x == n) {
            bail!("joint \"{n}\" is defined twice");
        }
        joints.push(n.to_string());
    }
    let shared_v = root.get("bones").and_then(|b| b.as_array()).filter(|b| !b.is_empty())
        .ok_or_else(|| anyhow!("bones must be a list with at least one bone"))?;
    let mut shared = Vec::new();
    bones(shared_v, &mut shared, &joints, None)?;
    let shared_sockets = match root.get("sockets") { Some(s) => sockets(s, &shared, None)?, None => Vec::new() };

    let empty = Map::new();
    let variants_o = match root.get("variants") { Some(x) => obj(x, "variants")?, None => &empty };
    let mut variants = Vec::new();
    for (name, vv) in variants_o {
        if !valid_name(name) {
            bail!("variant \"{name}\": a name is letters, digits and _");
        }
        let vo = obj(vv, &format!("variant \"{name}\""))?;
        let scale = match vo.get("scale") {
            None => 256,
            Some(s) => s.as_i64().filter(|&s| s > 0)
                .ok_or_else(|| anyhow!("variant \"{name}\": scale must be a whole number above 0 (256 = as modelled)"))?,
        };
        let mut all = shared.clone();
        if let Some(b) = vo.get("bones") {
            let b = b.as_array().ok_or_else(|| anyhow!("variant \"{name}\": bones must be a list"))?;
            bones(b, &mut all, &joints, Some(name))?;
        }
        let find = |b: &str, all: &[Bone], what: &str| -> Result<usize> {
            all.iter().position(|x| x.name == b).ok_or_else(|| anyhow!("variant \"{name}\": no bone \"{b}\" to {what}"))
        };
        if let Some(m) = vo.get("meshes") {
            for (b, x) in obj(m, &format!("variant \"{name}\": meshes"))? {
                let i = find(b, &all, "give a mesh")?;
                all[i].mesh = mesh_of(x, &format!("variant \"{name}\": the mesh of \"{b}\""))?;
            }
        }
        if let Some(o) = vo.get("offsets") {
            for (b, x) in obj(o, &format!("variant \"{name}\": offsets"))? {
                let i = find(b, &all, "move")?;
                all[i].offset = vec3(Some(x), &format!("variant \"{name}\": the offset of \"{b}\""))?;
            }
        }
        if let Some(r) = vo.get("rotate") {
            for (b, x) in obj(r, &format!("variant \"{name}\": rotate"))? {
                let i = find(b, &all, "turn")?;
                all[i].rotate = turns(x, &joints, &format!("variant \"{name}\", bone \"{b}\""))?;
            }
        }
        let socks = match vo.get("sockets") { Some(s) => sockets(s, &all, Some(name))?, None => shared_sockets.clone() };
        variants.push(Variant { name: name.clone(), scale, bones: all, sockets: socks });
    }
    if variants.is_empty() {
        variants.push(Variant { name: "default".into(), scale: 256, bones: shared.clone(), sockets: shared_sockets });
    }
    if let Some(exists) = mesh_exists {
        for v in &variants {
            for b in &v.bones {
                if let Some(m) = &b.mesh {
                    if !exists(m) {
                        bail!("variant \"{}\": bone \"{}\": no mesh \"{m}\" (assets/meshes)", v.name, b.name);
                    }
                }
            }
        }
    }
    let lib = SkelLib { joints, shared, variants };
    // a bone two variants add: one number, one parent; and two bones at one number (each
    // variant's own), one parent
    let mut at: HashMap<String, (usize, Option<usize>, String)> = HashMap::new();
    let mut by_number: HashMap<usize, (Option<usize>, String, String)> = HashMap::new();
    for v in &lib.variants {
        for (i, b) in v.bones.iter().enumerate() {
            if let Some((p, n, first)) = by_number.get(&i) {
                if *p != b.parent && *n != b.name {
                    bail!("bones \"{n}\" (variant \"{first}\") and \"{}\" (variant \"{}\") are both bone {i}: they must hang from the same parent", b.name, v.name);
                }
            } else {
                by_number.insert(i, (b.parent, b.name.clone(), v.name.clone()));
            }
            if let Some((j, p, first)) = at.get(&b.name) {
                if *j != i {
                    bail!("bone \"{}\" is bone {j} in variant \"{first}\" and bone {i} in \"{}\": a bone added by two variants must come at the same place in both", b.name, v.name);
                }
                if *p != b.parent {
                    bail!("bone \"{}\" hangs from different parents in variants \"{first}\" and \"{}\"", b.name, v.name);
                }
            } else {
                at.insert(b.name.clone(), (i, b.parent, v.name.clone()));
            }
        }
    }
    // two names that upper-case to the same constant
    let t = tables(&lib);
    let mut seen: HashMap<String, String> = HashMap::new();
    for (n, _, _) in &t.consts {
        let kind = n.split('_').next().unwrap_or("");
        if seen.insert(n.clone(), kind.to_string()).is_some() {
            bail!("two {} names are both {n} in capitals: rename one", kind.to_lowercase());
        }
    }
    Ok(lib)
}

/// Load a `.vskel`; mesh names are checked against the `.vmesh` files under the project's
/// `assets/meshes` (the folder beside the skeletons folder), when there is one.
pub fn load_vskel_file(path: &Path) -> Result<SkelLib> {
    let text = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let v: Value = serde_json::from_str(&text).with_context(|| format!("{}: not valid JSON", path.display()))?;
    let meshes = skeletons_dir(path).and_then(|s| s.parent().map(|a| a.join("meshes"))).filter(|m| m.is_dir());
    match meshes {
        Some(dir) => compile_vskel(&v, Some(&|n: &str| find_file(&dir, n, "vmesh").is_some())),
        None => compile_vskel(&v, None),
    }
}

/// The tables, by name: (constants, arrays), and the mesh names (for VPy's `T_MESHES`).
pub(crate) struct Tables {
    pub consts: Vec<(String, i64, Option<String>)>,
    pub arrays: Vec<(String, Vec<Vec<i64>>, String)>,
    pub meshes: Vec<String>,
}

pub(crate) fn tables(lib: &SkelLib) -> Tables {
    let mut consts: Vec<(String, i64, Option<String>)> = Vec::new();
    let mut arrays = Vec::new();
    // a mesh's file name may hold '-', ' ' or '.' (as the .vmesh symbols do)
    let up = |s: &str| s.to_uppercase().replace(['-', ' ', '.'], "_");
    let group = |count: &str, prefix: &str, names: &[String], note: &str, consts: &mut Vec<(String, i64, Option<String>)>| {
        consts.push((count.to_string(), names.len() as i64, Some(note.to_string())));
        for (i, n) in names.iter().enumerate() {
            consts.push((format!("{prefix}_{}", up(n)), i as i64, None));
        }
    };
    group("N_JOINTS", "JOINT", &lib.joints, "the joints: a pose's columns", &mut consts);

    // every bone, at its number: the shared ones as the skeleton defines them, a variant's own
    // as the first variant that adds it does
    let mut base: Vec<Bone> = lib.shared.clone();
    let mut names: Vec<String> = Vec::new();
    for v in &lib.variants {
        for (i, b) in v.bones.iter().enumerate() {
            if !names.contains(&b.name) {
                names.push(b.name.clone());
            }
            if base.len() <= i {
                base.push(b.clone());
            }
        }
    }
    // a bone number more than one bone name may share (two variants' own bones): each name
    // its number
    consts.push(("N_BONES".into(), base.len() as i64, Some("the bones: the shared ones, then the variants' own".into())));
    for n in &names {
        let i = lib.variants.iter().find_map(|v| v.bones.iter().position(|b| &b.name == n)).unwrap_or(0);
        consts.push((format!("BONE_{}", up(n)), i as i64, None));
    }
    let vnames: Vec<String> = lib.variants.iter().map(|v| v.name.clone()).collect();
    group("N_VARIANTS", "VARIANT", &vnames, "T_VARIANTS[variant]: scale (Q8), bone count", &mut consts);
    arrays.push(("T_VARIANTS".to_string(), lib.variants.iter().map(|v| vec![v.scale, v.bones.len() as i64]).collect(),
        "each variant's scale (Q8, 256 = as modelled) and how many bones it has".to_string()));

    // turn lists, each once
    let mut lists: Vec<Vec<Turn>> = Vec::new();
    let mut list_of = |r: &[Turn]| -> i64 {
        match lists.iter().position(|l| l.as_slice() == r) {
            Some(i) => i as i64,
            None => {
                lists.push(r.to_vec());
                lists.len() as i64 - 1
            }
        }
    };
    let bone_rows: Vec<Vec<i64>> = base.iter().map(|b| {
        let p = b.parent.map(|p| p as i64).unwrap_or(-1);
        vec![p, b.offset[0], b.offset[1], b.offset[2], list_of(&b.rotate)]
    }).collect();
    let mut over: Vec<Vec<i64>> = Vec::new();
    for (vi, v) in lib.variants.iter().enumerate() {
        for (i, b) in v.bones.iter().enumerate() {
            if b.offset != base[i].offset || b.rotate != base[i].rotate || b.name != base[i].name {
                over.push(vec![vi as i64, i as i64, b.offset[0], b.offset[1], b.offset[2], list_of(&b.rotate)]);
            }
        }
    }
    arrays.push(("T_BONES".to_string(), bone_rows,
        "each bone: parent (-1: the root), offset x y z as modelled, its turns (row of T_ROTS)".to_string()));
    let mut rots = Vec::new();
    let mut turn_rows = Vec::new();
    for l in &lists {
        rots.push(vec![turn_rows.len() as i64, l.len() as i64]);
        for t in l {
            turn_rows.push(vec![t.axis, t.joint.map(|j| j as i64).unwrap_or(-1), t.mul, t.div, t.add]);
        }
    }
    consts.push(("N_ROTS".into(), rots.len() as i64, Some("T_ROTS[list]: first turn, how many (0: unturned)".into())));
    consts.push(("N_TURNS".into(), turn_rows.len() as i64,
        Some("T_TURNS[turn]: axis (0 x, 1 y, 2 z), joint (-1: none), mul, div, add -- joint * mul / div + add".into())));
    let n_over = over.len() as i64;
    consts.push(("N_VARIANT_BONES".into(), n_over,
        Some("T_VARIANT_BONES[row]: variant, bone, offset x y z, turns -- where a variant differs from T_BONES".into())));
    arrays.push(("T_ROTS".to_string(), rots, "the turn lists: first row of T_TURNS, how many (the first outermost)".to_string()));
    // every table is there, so a program needs no conditional code: one with nothing in it
    // holds a row that is never read (its count says 0)
    if turn_rows.is_empty() {
        turn_rows.push(vec![0, -1, 1, 1, 0]);
    }
    arrays.push(("T_TURNS".to_string(), turn_rows,
        "every turn: axis (0 x, 1 y, 2 z), joint (-1: none), mul, div, add".to_string()));
    if over.is_empty() {
        over.push(vec![-1, -1, 0, 0, 0, 0]);
    }
    arrays.push(("T_VARIANT_BONES".to_string(), over,
        "a variant's own offset and turns for a bone: variant, bone, offset x y z, turns (row of T_ROTS)".to_string()));

    // meshes, by name
    let mut meshes: Vec<String> = lib.variants.iter().flat_map(|v| v.bones.iter().filter_map(|b| b.mesh.clone())).collect();
    meshes.sort();
    meshes.dedup();
    group("N_MESHES", "MESH", &meshes, "T_BONE_MESHES[variant][bone] (-1: none)", &mut consts);
    arrays.push(("T_BONE_MESHES".to_string(), lib.variants.iter().map(|v| (0..base.len()).map(|i| {
        v.bones.get(i).and_then(|b| b.mesh.as_ref()).map(|m| meshes.iter().position(|x| x == m).unwrap() as i64).unwrap_or(-1)
    }).collect()).collect(), "each variant's mesh on each bone (-1: none, or no such bone)".to_string()));

    // sockets
    let mut snames: Vec<String> = Vec::new();
    let mut defs: Vec<Vec<i64>> = Vec::new();
    for v in &lib.variants {
        for s in &v.sockets {
            if !snames.contains(&s.name) {
                snames.push(s.name.clone());
            }
        }
    }
    let mut per: Vec<Vec<i64>> = lib.variants.iter().map(|v| snames.iter().map(|n| match v.sockets.iter().find(|s| &s.name == n) {
        None => -1,
        Some(s) => {
            let row = vec![s.bone as i64, s.from[0], s.from[1], s.from[2], s.to[0], s.to[1], s.to[2]];
            match defs.iter().position(|d| d == &row) {
                Some(i) => i as i64,
                None => {
                    defs.push(row);
                    defs.len() as i64 - 1
                }
            }
        }
    }).collect()).collect();
    group("N_SOCKETS", "SOCKET", &snames, "T_VARIANT_SOCKETS[variant][socket]: row of T_SOCKETS (-1: none)", &mut consts);
    if snames.is_empty() {
        per = lib.variants.iter().map(|_| vec![-1]).collect();
        defs.push(vec![-1, 0, 0, 0, 0, 0, 0]);
    }
    arrays.push(("T_VARIANT_SOCKETS".to_string(), per, "each variant's sockets: row of T_SOCKETS (-1: it has none of that name)".to_string()));
    arrays.push(("T_SOCKETS".to_string(), defs,
        "the sockets: bone, from x y z, to x y z (in the bone's frame, as modelled)".to_string()));
    Tables { consts, arrays, meshes }
}

/// The skeleton as a C header: `<sym>_<NAME>` constants and `static const` arrays.
pub fn c_header(lib: &SkelLib, sym: &str, source: &str) -> String {
    let t = tables(lib);
    let guard = format!("VPY_ASSET_{sym}_VSKEL_H");
    let mut h = String::new();
    h.push_str(&format!("/* Auto-generated by `vpy_cli compile-asset` from {source}.\n"));
    h.push_str(" * The skeleton as constant tables (docs/ASSETS.md, .vskel): do not edit by hand.\n");
    h.push_str(" * MESH_<m> numbers the meshes by name; the program says which loaded mesh each one is. */\n");
    h.push_str(&format!("#ifndef {guard}\n#define {guard}\n\n#include <stdint.h>\n\n"));
    for (name, value, note) in &t.consts {
        if let Some(n) = note {
            h.push_str(&format!("\n/* {n} */\n"));
        }
        h.push_str(&format!("#define {sym}_{name} {value}\n"));
    }
    h.push_str("\n/* the meshes' names, by MESH_<m> */\n");
    h.push_str(&format!("#define {sym}_MESH_NAMES {{ {} }}\n",
        t.meshes.iter().map(|m| format!("\"{m}\"")).collect::<Vec<_>>().join(", ")));
    for (name, rows, note) in &t.arrays {
        let within = |lo: i64, hi: i64| rows.iter().flatten().all(|&x| (lo..=hi).contains(&x));
        let ty = if within(i8::MIN as i64, i8::MAX as i64) { "int8_t" }
            else if within(i16::MIN as i64, i16::MAX as i64) { "int16_t" } else { "int32_t" };
        let w = rows.first().map(|r| r.len()).unwrap_or(0);
        h.push_str(&format!("\n/* {note} */\nstatic const {ty} {sym}_{name}[{}][{w}] = {{\n", rows.len()));
        for r in rows {
            h.push_str(&format!("    {{ {} }},\n", r.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(", ")));
        }
        h.push_str("};\n");
    }
    h.push_str(&format!("\n#endif /* {guard} */\n"));
    h
}

/// The skeleton as VPy source: a module of `const`s (`import <name>`), with `T_MESHES`, each
/// mesh's `MESH("name")` slot.
pub fn vpy_module(lib: &SkelLib, source: &str) -> String {
    let t = tables(lib);
    let mut s = format!("# Generated from {source}: the skeleton as constants.\n");
    for (name, value, note) in &t.consts {
        if let Some(n) = note {
            s.push_str(&format!("\n# {n}\n"));
        }
        s.push_str(&format!("const {name} = {value}\n"));
    }
    if !t.meshes.is_empty() {
        s.push_str("\n# each mesh's slot (MESH_<m> -> MESH(\"name\"))\nconst T_MESHES = [");
        s.push_str(&t.meshes.iter().map(|m| format!("MESH(\"{m}\")")).collect::<Vec<_>>().join(", "));
        s.push_str("]\n");
    }
    for (name, rows, note) in &t.arrays {
        s.push_str(&format!("\n# {note}\nconst {name} = [\n"));
        for r in rows {
            s.push_str(&format!("    [{}],\n", r.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(", ")));
        }
        s.push_str("]\n");
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    fn skel() -> Value {
        serde_json::json!({
            "version": 1, "angle_unit": 4096,
            "joints": [ {"name": "twist"}, {"name": "elbow"} ],
            "bones": [
                { "name": "hips", "parent": null, "offset": [0, 950, 0], "mesh": "hips", "rotate": [] },
                { "name": "torso", "parent": "hips", "offset": [0, 0, 0], "mesh": "torso",
                  "rotate": [ {"axis": "y", "joint": "twist"}, {"axis": "x", "joint": "elbow", "mul": -1, "div": 2, "add": 284} ] },
                { "name": "head", "parent": "torso", "offset": [0, 680, 0], "mesh": "head", "rotate": [ {"axis": "y", "joint": "twist"} ] }
            ],
            "sockets": [ { "name": "blade", "bone": "head", "from": [0, 0, 0], "to": [0, -1200, 0] } ],
            "variants": {
                "yoda": { "scale": 72, "meshes": { "head": "big_head", "hips": null }, "offsets": { "head": [0, 640, 0] } },
                "four": { "scale": 300, "bones": [ { "name": "arm2", "parent": "torso", "offset": [380, 330, 0], "mesh": "torso",
                          "rotate": [ {"axis": "z", "add": 455} ] } ],
                          "rotate": { "head": [] },
                          "sockets": [ { "name": "blade", "bone": "head", "from": [0, 0, 0], "to": [0, -1200, 0] },
                                       { "name": "blade2", "bone": "arm2", "from": [0, 0, 0], "to": [0, -1000, 0] } ] }
            }
        })
    }

    #[test]
    fn gathers_the_tables() {
        let l = compile_vskel(&skel(), None).unwrap();
        assert_eq!(l.variants.iter().map(|v| v.name.as_str()).collect::<Vec<_>>(), vec!["four", "yoda"]);
        let t = tables(&l);
        let a = |n: &str| t.arrays.iter().find(|x| x.0 == n).unwrap().1.clone();
        let c = |n: &str| t.consts.iter().find(|x| x.0 == n).unwrap().1;
        assert_eq!(c("N_BONES"), 4);
        assert_eq!(c("BONE_ARM2"), 3);
        assert_eq!(c("VARIANT_YODA"), 1);
        assert_eq!(a("T_VARIANTS"), vec![vec![300, 4], vec![72, 3]]);
        // the lists: [] , [y twist, x elbow], [y twist], [z 455]
        assert_eq!(a("T_BONES"), vec![vec![-1, 0, 950, 0, 0], vec![0, 0, 0, 0, 1], vec![1, 0, 680, 0, 2], vec![1, 380, 330, 0, 3]]);
        assert_eq!(a("T_ROTS"), vec![vec![0, 0], vec![0, 2], vec![2, 1], vec![3, 1]]);
        assert_eq!(a("T_TURNS"), vec![vec![1, 0, 1, 1, 0], vec![0, 1, -1, 2, 284], vec![1, 0, 1, 1, 0], vec![2, -1, 1, 1, 455]]);
        // four's head unturned, yoda's head lower
        assert_eq!(a("T_VARIANT_BONES"), vec![vec![0, 2, 0, 680, 0, 0], vec![1, 2, 0, 640, 0, 2]]);
        assert_eq!(t.meshes, vec!["big_head", "head", "hips", "torso"]);
        assert_eq!(a("T_BONE_MESHES"), vec![vec![2, 3, 1, 3], vec![-1, 3, 0, -1]]);
        assert_eq!(a("T_VARIANT_SOCKETS"), vec![vec![0, 1], vec![0, -1]]);
        assert_eq!(a("T_SOCKETS"), vec![vec![2, 0, 0, 0, 0, -1200, 0], vec![3, 0, 0, 0, 0, -1000, 0]]);
    }

    #[test]
    fn c_and_vpy_say_the_same() {
        let l = compile_vskel(&skel(), None).unwrap();
        let h = c_header(&l, "BODY", "body.vskel");
        assert!(h.contains("#define BODY_BONE_ARM2 3"));
        assert!(h.contains("#define BODY_MESH_NAMES { \"big_head\", \"head\", \"hips\", \"torso\" }"));
        assert!(h.contains("static const int16_t BODY_T_BONES[4][5]"));
        assert!(h.contains("static const int8_t BODY_T_BONE_MESHES[2][4]"));
        let v = vpy_module(&l, "body.vskel");
        assert!(v.contains("const T_MESHES = [MESH(\"big_head\"), MESH(\"head\"), MESH(\"hips\"), MESH(\"torso\")]\n"));
        assert!(v.contains("const VARIANT_FOUR = 0\n"));
        let tokens = vpy_parser::lex(&v).unwrap();
        vpy_parser::parser::parse(tokens, "body.vskel").unwrap();
    }

    #[test]
    fn no_variants_is_one_default() {
        let mut s = skel();
        s.as_object_mut().unwrap().remove("variants");
        let l = compile_vskel(&s, None).unwrap();
        assert_eq!(l.variants.len(), 1);
        assert_eq!(l.variants[0].name, "default");
        assert_eq!(l.variants[0].sockets.len(), 1);
        // nothing differs from the shared bones, and no sockets: the tables are still there
        s["sockets"] = serde_json::json!([]);
        let t = tables(&compile_vskel(&s, None).unwrap());
        let a = |n: &str| t.arrays.iter().find(|x| x.0 == n).unwrap().1.clone();
        let c = |n: &str| t.consts.iter().find(|x| x.0 == n).unwrap().1;
        assert_eq!((c("N_VARIANT_BONES"), a("T_VARIANT_BONES")), (0, vec![vec![-1, -1, 0, 0, 0, 0]]));
        assert_eq!((c("N_SOCKETS"), a("T_VARIANT_SOCKETS")), (0, vec![vec![-1]]));
    }

    #[test]
    fn refuses_what_the_editor_refuses() {
        let bad = |f: &dyn Fn(&mut Value), want: &str| {
            let mut v = skel();
            f(&mut v);
            let e = compile_vskel(&v, Some(&|m: &str| m != "gone")).unwrap_err().to_string();
            assert!(e.contains(want), "{e} / {want}");
        };
        bad(&|v| { v["version"] = 2.into(); }, "version must be 1");
        bad(&|v| { v["bones"][1]["parent"] = "head".into(); }, "its parent \"head\" must be a bone listed before it");
        bad(&|v| { v["bones"][2]["name"] = "torso".into(); }, "bone \"torso\" is defined twice");
        bad(&|v| { v["bones"][1]["rotate"][0]["joint"] = "knee".into(); }, "no joint \"knee\"");
        bad(&|v| { v["bones"][1]["rotate"][1]["div"] = 0.into(); }, "div cannot be 0");
        bad(&|v| { v["bones"][1]["rotate"][0]["axis"] = "w".into(); }, "needs an axis x, y or z");
        bad(&|v| { v["variants"]["yoda"]["meshes"]["tail"] = "head".into(); }, "no bone \"tail\" to give a mesh");
        bad(&|v| { v["variants"]["yoda"]["meshes"]["head"] = "gone".into(); }, "no mesh \"gone\"");
        bad(&|v| { v["sockets"][0]["bone"] = "arm2".into(); }, "socket \"blade\": no bone \"arm2\"");
        bad(&|v| { v["sockets"][0]["name"] = "a blade".into(); }, "socket 0: needs a name");
        bad(&|v| { v["variants"]["yoda"]["bones"] = serde_json::json!([
            { "name": "x", "parent": "torso", "offset": [0, 0, 0], "mesh": null },
            { "name": "arm2", "parent": "torso", "offset": [0, 0, 0], "mesh": null } ]); }, "must come at the same place in both");
        bad(&|v| { v["variants"]["yoda"]["bones"] = serde_json::json!([
            { "name": "arm2", "parent": "hips", "offset": [0, 0, 0], "mesh": null } ]); }, "hangs from different parents");
        bad(&|v| { v["variants"]["yoda"]["meshes"]["head"] = "Head".into(); }, "two mesh names are both MESH_HEAD");
    }
}
