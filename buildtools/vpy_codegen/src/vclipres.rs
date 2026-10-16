//! `.vclip` — a library of 3D poses, animation clips and sets on a `.vskel` skeleton
//! (docs/ASSETS.md), made into constant tables a game reads: the same tables as a C header
//! (`vpy_cli compile-asset x.vclip --format c`) and as a VPy module (`import x` finds
//! `assets/clips/**/x.vclip`).
//!
//! Every name becomes an index constant and every table a flat array of whole numbers, so a
//! program needs nothing from a runtime to read them:
//!
//! | name | what |
//! |---|---|
//! | `N_JOINTS`, `JOINT_<j>` | the skeleton's joints, in its order: a pose's columns |
//! | `N_POSES`, `POSE_<p>`, `T_POSES[N_POSES][N_JOINTS]` | the poses' angles |
//! | `N_CLIPS`, `CLIP_<c>`, `T_CLIPS[N_CLIPS][4]` | first key, key count, length (frames), loop |
//! | `N_KEYS`, `T_KEYS[N_KEYS][2]` | frame, pose -- every clip's keys, one clip after another |
//! | `N_PROPS`, `PROP_<k>`, `T_CLIP_PROPS[N_CLIPS][N_PROPS]` | the clips' properties (0 if absent) |
//! | `N_MARKS`, `MARK_<m>`, `N_MARK_ROWS`, `T_MARKS[..][4]` | clip, frame, mark, value (0 if absent) |
//! | `N_SETS`, `SET_<s>` | the sets |
//! | `N_STANCES`, `STANCE_<r>`, `T_SET_POSES[N_SETS][N_STANCES]` | a set's pose per stance (-1 if absent) |
//! | `N_ROLES`, `ROLE_<r>`, `T_SET_CLIPS[N_SETS][N_ROLES]` | a set's clip per role (-1 if absent) |
//! | `N_SPROPS`, `SPROP_<k>`, `T_SET_PROPS[N_SETS][N_SPROPS]` | a set's properties (0 if absent) |
//!
//! Names are upper-cased (`maul_guard` → `POSE_MAUL_GUARD`). Poses, clips and sets are
//! numbered in the alphabetical order of their names; property, mark, stance and role columns
//! in the order each name is first met going through them that way. A program reads them by
//! name, never by number. A table with no rows or no columns is left out (its count is 0). In C every name carries the library's prefix
//! (`FIGHTERS_POSE_MAUL_GUARD`, `FIGHTERS_T_POSES`), and each array has the narrowest type
//! that holds its values (`int8_t`, `int16_t` or `int32_t`; `T_POSES` at least `int16_t`):
//! index the arrays rather than taking pointers of a fixed type.

use anyhow::{anyhow, bail, Context, Result};
use serde_json::{Map, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct Clip {
    pub name: String,
    /// (frame, pose index)
    pub keys: Vec<(i64, usize)>,
    pub looping: bool,
    pub props: HashMap<String, i64>,
    /// (frame, mark index, value)
    pub marks: Vec<(i64, usize, Option<i64>)>,
}

#[derive(Debug, Clone)]
pub struct Set {
    pub name: String,
    pub poses: HashMap<String, usize>,
    pub clips: HashMap<String, usize>,
    pub props: HashMap<String, i64>,
}

#[derive(Debug, Clone)]
pub struct ClipLib {
    pub skeleton: String,
    pub joints: Vec<String>,
    pub poses: Vec<(String, Vec<i64>)>,
    pub clips: Vec<Clip>,
    pub props: Vec<String>,
    pub marks: Vec<String>,
    pub sets: Vec<Set>,
    pub stances: Vec<String>,
    pub roles: Vec<String>,
    pub sprops: Vec<String>,
}

fn valid_name(n: &str) -> bool {
    let mut c = n.chars();
    matches!(c.next(), Some(ch) if ch.is_ascii_alphabetic() || ch == '_') && c.all(|ch| ch.is_ascii_alphanumeric() || ch == '_')
}

fn int(v: &Value, what: &str) -> Result<i64> {
    v.as_i64().ok_or_else(|| anyhow!("{what} must be a whole number"))
}

fn obj<'a>(v: &'a Value, what: &str) -> Result<&'a Map<String, Value>> {
    v.as_object().ok_or_else(|| anyhow!("{what} must be an object"))
}

/// Where the skeletons are, for a library at `clip`: the `skeletons` folder beside the
/// nearest `clips` folder up the path (assets/clips/x.vclip → assets/skeletons).
pub fn skeletons_dir(clip: &Path) -> Option<PathBuf> {
    clip.ancestors().skip(1).find_map(|d| {
        let s = d.join("skeletons");
        s.is_dir().then_some(s)
    })
}

/// `name.vskel` anywhere under `dir`.
pub fn find_file(dir: &Path, name: &str, ext: &str) -> Option<PathBuf> {
    let entries = std::fs::read_dir(dir).ok()?;
    let mut subdirs = Vec::new();
    for e in entries.flatten() {
        let p = e.path();
        if p.is_dir() {
            subdirs.push(p);
        } else if p.extension().and_then(|x| x.to_str()).is_some_and(|x| x.eq_ignore_ascii_case(ext))
            && p.file_stem().and_then(|s| s.to_str()) == Some(name)
        {
            return Some(p);
        }
    }
    subdirs.sort();
    subdirs.iter().find_map(|d| find_file(d, name, ext))
}

/// The joint names of a `.vskel`, in order (what a pose's columns are).
pub fn skeleton_joints(path: &Path) -> Result<Vec<String>> {
    let text = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let v: Value = serde_json::from_str(&text).with_context(|| format!("{}: not valid JSON", path.display()))?;
    let joints = v.get("joints").and_then(|j| j.as_array()).ok_or_else(|| anyhow!("{}: joints must be a list", path.display()))?;
    let mut out = Vec::new();
    for (k, j) in joints.iter().enumerate() {
        let n = j.get("name").and_then(|n| n.as_str()).ok_or_else(|| anyhow!("{}: joint {k} needs a name", path.display()))?;
        if out.iter().any(|x| x == n) {
            bail!("{}: joint \"{n}\" is defined twice", path.display());
        }
        out.push(n.to_string());
    }
    Ok(out)
}

/// Load a `.vclip` and the joints of the skeleton it names.
pub fn load_vclip_file(path: &Path) -> Result<ClipLib> {
    let text = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let v: Value = serde_json::from_str(&text).with_context(|| format!("{}: not valid JSON", path.display()))?;
    let skel = v.get("skeleton").and_then(|s| s.as_str()).ok_or_else(|| anyhow!("skeleton must name a .vskel"))?;
    let dir = skeletons_dir(path).ok_or_else(|| anyhow!("no skeletons folder beside the clips folder (assets/skeletons) for {}", path.display()))?;
    let sk = find_file(&dir, skel, "vskel").ok_or_else(|| anyhow!("no skeleton \"{skel}\" in {}", dir.display()))?;
    let joints = skeleton_joints(&sk)?;
    compile_vclip(&v, &joints)
}

/// Check a `.vclip` against the skeleton's joints and gather it into tables. The errors are
/// the editor's (ide/frontend/src/components/anim3d/animModel.ts validateVclip).
pub fn compile_vclip(v: &Value, joints: &[String]) -> Result<ClipLib> {
    let root = obj(v, "a .vclip")?;
    if root.get("version").and_then(|x| x.as_i64()) != Some(1) {
        bail!("version must be 1");
    }
    let skeleton = root.get("skeleton").and_then(|s| s.as_str()).ok_or_else(|| anyhow!("skeleton must name a .vskel"))?.to_string();
    let empty = Map::new();
    let poses_o = match root.get("poses") { Some(p) => obj(p, "poses")?, None => &empty };
    let clips_o = match root.get("clips") { Some(p) => obj(p, "clips")?, None => &empty };
    let sets_o = match root.get("sets") { Some(p) => obj(p, "sets")?, None => &empty };

    let mut poses = Vec::new();
    let mut pose_ix = HashMap::new();
    for (name, p) in poses_o {
        if !valid_name(name) {
            bail!("pose \"{name}\": a name is letters, digits and _");
        }
        let p = obj(p, &format!("pose \"{name}\""))?;
        for k in p.keys() {
            if !joints.contains(k) {
                bail!("pose \"{name}\": the skeleton has no joint \"{k}\"");
            }
        }
        let mut row = Vec::new();
        for j in joints {
            let a = p.get(j).ok_or_else(|| anyhow!("pose \"{name}\" has no angle for \"{j}\""))?;
            row.push(int(a, &format!("pose \"{name}\": {j}"))?);
        }
        pose_ix.insert(name.clone(), poses.len());
        poses.push((name.clone(), row));
    }

    let mut props: Vec<String> = Vec::new();
    let mut marks: Vec<String> = Vec::new();
    let mut clips = Vec::new();
    let mut clip_ix = HashMap::new();
    for (name, c) in clips_o {
        if !valid_name(name) {
            bail!("clip \"{name}\": a name is letters, digits and _");
        }
        let c = obj(c, &format!("clip \"{name}\""))?;
        let keys_v = c.get("keys").and_then(|k| k.as_array()).filter(|k| !k.is_empty())
            .ok_or_else(|| anyhow!("clip \"{name}\" needs at least one key"))?;
        let mut keys = Vec::new();
        let mut last = -1i64;
        for (i, k) in keys_v.iter().enumerate() {
            let f = int(k.get("frame").unwrap_or(&Value::Null), &format!("clip \"{name}\": key {i}: frame"))?;
            if f < 0 {
                bail!("clip \"{name}\": key {i}: frame must be a whole number from 0");
            }
            if f <= last {
                bail!("clip \"{name}\": key {i} (frame {f}) must come after frame {last}");
            }
            last = f;
            let p = k.get("pose").and_then(|p| p.as_str()).unwrap_or("");
            let pi = *pose_ix.get(p).ok_or_else(|| anyhow!("clip \"{name}\": key {i}: no pose \"{p}\""))?;
            keys.push((f, pi));
        }
        let looping = match c.get("loop") {
            None => false,
            Some(Value::Bool(b)) => *b,
            Some(_) => bail!("clip \"{name}\": loop must be true or false"),
        };
        let mut cprops = HashMap::new();
        if let Some(p) = c.get("props") {
            for (k, x) in obj(p, &format!("clip \"{name}\": props"))? {
                if !valid_name(k) {
                    bail!("clip \"{name}\": property \"{k}\": a name is letters, digits and _");
                }
                cprops.insert(k.clone(), int(x, &format!("clip \"{name}\": {k}"))?);
                if !props.contains(k) {
                    props.push(k.clone());
                }
            }
        }
        let mut cmarks = Vec::new();
        if let Some(m) = c.get("marks") {
            let m = m.as_array().ok_or_else(|| anyhow!("clip \"{name}\": marks must be a list"))?;
            for (i, mk) in m.iter().enumerate() {
                let mn = mk.get("name").and_then(|n| n.as_str()).filter(|n| !n.is_empty())
                    .ok_or_else(|| anyhow!("clip \"{name}\": mark {i} needs a name"))?;
                if !valid_name(mn) {
                    bail!("clip \"{name}\": mark \"{mn}\": a name is letters, digits and _");
                }
                let f = int(mk.get("frame").unwrap_or(&Value::Null), &format!("clip \"{name}\": mark \"{mn}\": frame"))?;
                if f < 0 || f > last {
                    bail!("clip \"{name}\": mark \"{mn}\" must fall on the clip (frame 0 to {last})");
                }
                let value = match mk.get("value") { None => None, Some(x) => Some(int(x, &format!("clip \"{name}\": mark \"{mn}\": value"))?) };
                let mi = match marks.iter().position(|x| x == mn) { Some(i) => i, None => { marks.push(mn.to_string()); marks.len() - 1 } };
                cmarks.push((f, mi, value));
            }
        }
        clip_ix.insert(name.clone(), clips.len());
        clips.push(Clip { name: name.clone(), keys, looping, props: cprops, marks: cmarks });
    }

    let mut stances: Vec<String> = Vec::new();
    let mut roles: Vec<String> = Vec::new();
    let mut sprops: Vec<String> = Vec::new();
    let mut sets = Vec::new();
    for (name, s) in sets_o {
        if !valid_name(name) {
            bail!("set \"{name}\": a name is letters, digits and _");
        }
        let s = obj(s, &format!("set \"{name}\""))?;
        let mut sp = HashMap::new();
        if let Some(p) = s.get("poses") {
            for (role, x) in obj(p, &format!("set \"{name}\": poses"))? {
                if !valid_name(role) {
                    bail!("set \"{name}\": stance \"{role}\": a name is letters, digits and _");
                }
                let pn = x.as_str().unwrap_or("");
                sp.insert(role.clone(), *pose_ix.get(pn).ok_or_else(|| anyhow!("set \"{name}\": {role}: no pose \"{pn}\""))?);
                if !stances.contains(role) {
                    stances.push(role.clone());
                }
            }
        }
        let mut sc = HashMap::new();
        if let Some(p) = s.get("clips") {
            for (role, x) in obj(p, &format!("set \"{name}\": clips"))? {
                if !valid_name(role) {
                    bail!("set \"{name}\": role \"{role}\": a name is letters, digits and _");
                }
                let cn = x.as_str().unwrap_or("");
                sc.insert(role.clone(), *clip_ix.get(cn).ok_or_else(|| anyhow!("set \"{name}\": {role}: no clip \"{cn}\""))?);
                if !roles.contains(role) {
                    roles.push(role.clone());
                }
            }
        }
        let mut spr = HashMap::new();
        if let Some(p) = s.get("props") {
            for (k, x) in obj(p, &format!("set \"{name}\": props"))? {
                if !valid_name(k) {
                    bail!("set \"{name}\": property \"{k}\": a name is letters, digits and _");
                }
                spr.insert(k.clone(), int(x, &format!("set \"{name}\": {k}"))?);
                if !sprops.contains(k) {
                    sprops.push(k.clone());
                }
            }
        }
        sets.push(Set { name: name.clone(), poses: sp, clips: sc, props: spr });
    }

    let lib = ClipLib { skeleton, joints: joints.to_vec(), poses, clips, props, marks, sets, stances, roles, sprops };
    // two names that upper-case to the same constant
    for (what, names) in [
        ("joint", lib.joints.clone()),
        ("pose", lib.poses.iter().map(|p| p.0.clone()).collect()),
        ("clip", lib.clips.iter().map(|c| c.name.clone()).collect()),
        ("set", lib.sets.iter().map(|s| s.name.clone()).collect()),
        ("property", lib.props.clone()),
        ("mark", lib.marks.clone()),
        ("stance", lib.stances.clone()),
        ("role", lib.roles.clone()),
        ("set property", lib.sprops.clone()),
    ] {
        let mut seen: HashMap<String, String> = HashMap::new();
        for n in names {
            if let Some(o) = seen.insert(n.to_uppercase(), n.clone()) {
                bail!("{what}s \"{o}\" and \"{n}\" are the same name in capitals: rename one");
            }
        }
    }
    Ok(lib)
}

/// The tables, by name: (constants, arrays). One description serves the C header and the
/// VPy module.
struct Tables {
    consts: Vec<(String, i64, Option<String>)>,
    arrays: Vec<(String, Vec<Vec<i64>>, String)>,
}

fn tables(lib: &ClipLib) -> Tables {
    let mut consts: Vec<(String, i64, Option<String>)> = Vec::new();
    let mut arrays = Vec::new();
    let up = |s: &str| s.to_uppercase();
    let group = |count: &str, prefix: &str, names: &[String], note: &str, consts: &mut Vec<(String, i64, Option<String>)>| {
        consts.push((count.to_string(), names.len() as i64, Some(note.to_string())));
        for (i, n) in names.iter().enumerate() {
            consts.push((format!("{prefix}_{}", up(n)), i as i64, None));
        }
    };
    group("N_JOINTS", "JOINT", &lib.joints, "the skeleton's joints: a pose's columns", &mut consts);
    let pose_names: Vec<String> = lib.poses.iter().map(|p| p.0.clone()).collect();
    group("N_POSES", "POSE", &pose_names, "T_POSES[pose][joint]: the angles", &mut consts);
    if !lib.poses.is_empty() && !lib.joints.is_empty() {
        arrays.push(("T_POSES".to_string(), lib.poses.iter().map(|p| p.1.clone()).collect(), "the poses: one angle per joint".to_string()));
    }
    let clip_names: Vec<String> = lib.clips.iter().map(|c| c.name.clone()).collect();
    group("N_CLIPS", "CLIP", &clip_names, "T_CLIPS[clip]: first key, keys, length, loop", &mut consts);
    let mut keys = Vec::new();
    let mut rows = Vec::new();
    for c in &lib.clips {
        rows.push(vec![keys.len() as i64, c.keys.len() as i64, c.keys.last().map(|k| k.0).unwrap_or(0), c.looping as i64]);
        for k in &c.keys {
            keys.push(vec![k.0, k.1 as i64]);
        }
    }
    consts.push(("N_KEYS".to_string(), keys.len() as i64, Some("T_KEYS[key]: frame, pose".to_string())));
    if !rows.is_empty() {
        arrays.push(("T_CLIPS".to_string(), rows, "the clips: first key in T_KEYS, how many keys, length in frames, loops".to_string()));
        arrays.push(("T_KEYS".to_string(), keys, "every clip's keys, one clip after another: frame, pose".to_string()));
    }
    group("N_PROPS", "PROP", &lib.props, "T_CLIP_PROPS[clip][prop] (0 if absent)", &mut consts);
    if !lib.clips.is_empty() && !lib.props.is_empty() {
        arrays.push(("T_CLIP_PROPS".to_string(),
            lib.clips.iter().map(|c| lib.props.iter().map(|p| *c.props.get(p).unwrap_or(&0)).collect()).collect(),
            "the clips' properties (0 if absent)".to_string()));
    }
    group("N_MARKS", "MARK", &lib.marks, "the mark names (T_MARKS's third column)", &mut consts);
    let mrows: Vec<Vec<i64>> = lib.clips.iter().enumerate()
        .flat_map(|(ci, c)| c.marks.iter().map(move |m| vec![ci as i64, m.0, m.1 as i64, m.2.unwrap_or(0)]))
        .collect();
    consts.push(("N_MARK_ROWS".to_string(), mrows.len() as i64, Some("T_MARKS[row]: clip, frame, mark, value".to_string())));
    if !mrows.is_empty() {
        arrays.push(("T_MARKS".to_string(), mrows, "every mark: clip, frame, mark, value (0 if absent)".to_string()));
    }
    let set_names: Vec<String> = lib.sets.iter().map(|s| s.name.clone()).collect();
    group("N_SETS", "SET", &set_names, "the sets", &mut consts);
    group("N_STANCES", "STANCE", &lib.stances, "T_SET_POSES[set][stance] (-1 if absent)", &mut consts);
    group("N_ROLES", "ROLE", &lib.roles, "T_SET_CLIPS[set][role] (-1 if absent)", &mut consts);
    group("N_SPROPS", "SPROP", &lib.sprops, "T_SET_PROPS[set][prop] (0 if absent)", &mut consts);
    if !lib.sets.is_empty() {
        if !lib.stances.is_empty() {
            arrays.push(("T_SET_POSES".to_string(),
                lib.sets.iter().map(|s| lib.stances.iter().map(|r| s.poses.get(r).map(|&i| i as i64).unwrap_or(-1)).collect()).collect(),
                "each set's pose per stance (-1 if absent)".to_string()));
        }
        if !lib.roles.is_empty() {
            arrays.push(("T_SET_CLIPS".to_string(),
                lib.sets.iter().map(|s| lib.roles.iter().map(|r| s.clips.get(r).map(|&i| i as i64).unwrap_or(-1)).collect()).collect(),
                "each set's clip per role (-1 if absent)".to_string()));
        }
        if !lib.sprops.is_empty() {
            arrays.push(("T_SET_PROPS".to_string(),
                lib.sets.iter().map(|s| lib.sprops.iter().map(|p| *s.props.get(p).unwrap_or(&0)).collect()).collect(),
                "each set's properties (0 if absent)".to_string()));
        }
    }
    Tables { consts, arrays }
}

/// The library as a C header: `<sym>_<NAME>` constants and `static const` arrays.
pub fn c_header(lib: &ClipLib, sym: &str, source: &str) -> String {
    let t = tables(lib);
    let guard = format!("VPY_ASSET_{sym}_VCLIP_H");
    let mut h = String::new();
    h.push_str(&format!("/* Auto-generated by `vpy_cli compile-asset` from {source} (skeleton \"{}\").\n", lib.skeleton));
    h.push_str(" * Poses, clips and sets as constant tables (docs/ASSETS.md, .vclip): do not edit by hand. */\n");
    h.push_str(&format!("#ifndef {guard}\n#define {guard}\n\n#include <stdint.h>\n\n"));
    for (name, value, note) in &t.consts {
        if let Some(n) = note {
            h.push_str(&format!("\n/* {n} */\n"));
        }
        h.push_str(&format!("#define {sym}_{name} {value}\n"));
    }
    for (name, rows, note) in &t.arrays {
        // the narrowest type that holds every value; the poses at least 16 bits, so a program
        // can read a row as an int16_t angle per joint whatever its values
        let within = |lo: i64, hi: i64| rows.iter().flatten().all(|&x| (lo..=hi).contains(&x));
        let ty = if name != "T_POSES" && within(i8::MIN as i64, i8::MAX as i64) { "int8_t" }
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

/// The library as VPy source: a module of `const`s (`import <name>`).
pub fn vpy_module(lib: &ClipLib, source: &str) -> String {
    let t = tables(lib);
    let mut s = format!("# Generated from {source} (skeleton \"{}\"): poses, clips and sets as constants.\n", lib.skeleton);
    for (name, value, note) in &t.consts {
        if let Some(n) = note {
            s.push_str(&format!("\n# {n}\n"));
        }
        s.push_str(&format!("const {name} = {value}\n"));
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

    fn lib() -> Value {
        serde_json::json!({
            "version": 1, "skeleton": "fig",
            "poses": { "g": {"a": 0, "b": 1}, "w": {"a": 400, "b": -40000} },
            "clips": {
                "cut": { "keys": [{"frame": 0, "pose": "g"}, {"frame": 4, "pose": "w"}, {"frame": 9, "pose": "g"}],
                         "props": {"damage": 2}, "marks": [{"frame": 4, "name": "strike", "value": 3}] },
                "idle": { "keys": [{"frame": 0, "pose": "g"}], "loop": true, "props": {"lunge": 7} }
            },
            "sets": { "me": { "poses": {"guard": "g"}, "clips": {"slash": "cut"}, "props": {"combo": 30} },
                      "you": { "clips": {"slash": "idle", "rest": "idle"} } }
        })
    }
    const J: [&str; 2] = ["a", "b"];
    fn joints() -> Vec<String> { J.iter().map(|s| s.to_string()).collect() }

    #[test]
    fn gathers_the_tables() {
        let l = compile_vclip(&lib(), &joints()).unwrap();
        assert_eq!(l.poses[1].1, vec![400, -40000]);
        assert_eq!(l.clips[0].keys, vec![(0, 0), (4, 1), (9, 0)]);
        assert_eq!(l.props, vec!["damage", "lunge"]);
        assert_eq!(l.roles, vec!["slash", "rest"]);
        let t = tables(&l);
        let a = |n: &str| t.arrays.iter().find(|x| x.0 == n).unwrap().1.clone();
        assert_eq!(a("T_CLIPS"), vec![vec![0, 3, 9, 0], vec![3, 1, 0, 1]]);
        assert_eq!(a("T_KEYS"), vec![vec![0, 0], vec![4, 1], vec![9, 0], vec![0, 0]]);
        assert_eq!(a("T_CLIP_PROPS"), vec![vec![2, 0], vec![0, 7]]);
        assert_eq!(a("T_MARKS"), vec![vec![0, 4, 0, 3]]);
        assert_eq!(a("T_SET_POSES"), vec![vec![0], vec![-1]]);
        assert_eq!(a("T_SET_CLIPS"), vec![vec![0, -1], vec![1, 1]]);
        assert_eq!(a("T_SET_PROPS"), vec![vec![30], vec![0]]);
    }

    #[test]
    fn c_and_vpy_say_the_same() {
        let l = compile_vclip(&lib(), &joints()).unwrap();
        let h = c_header(&l, "MOVES", "moves.vclip");
        assert!(h.contains("#define MOVES_POSE_W 1"));
        assert!(h.contains("#define MOVES_ROLE_REST 1"));
        assert!(h.contains("static const int32_t MOVES_T_POSES[2][2]"));     // -40000 needs 32 bits
        assert!(h.contains("static const int8_t MOVES_T_KEYS[4][2]"));
        let v = vpy_module(&l, "moves.vclip");
        assert!(v.contains("const POSE_W = 1\n"));
        assert!(v.contains("const T_SET_CLIPS = [\n    [0, -1],\n    [1, 1],\n]"));
        let tokens = vpy_parser::lex(&v).unwrap();
        vpy_parser::parser::parse(tokens, "moves.vclip").unwrap();
    }

    #[test]
    fn refuses_what_the_editor_refuses() {
        let bad = |f: &dyn Fn(&mut Value), want: &str| {
            let mut v = lib();
            f(&mut v);
            let e = compile_vclip(&v, &joints()).unwrap_err().to_string();
            assert!(e.contains(want), "{e} / {want}");
        };
        bad(&|v| { v["poses"]["w"].as_object_mut().unwrap().remove("b"); }, "pose \"w\" has no angle for \"b\"");
        bad(&|v| { v["poses"]["w"]["c"] = 1.into(); }, "the skeleton has no joint \"c\"");
        bad(&|v| { v["clips"]["cut"]["keys"][1]["frame"] = 0.into(); }, "must come after frame 0");
        bad(&|v| { v["clips"]["cut"]["keys"][1]["pose"] = "zz".into(); }, "no pose \"zz\"");
        bad(&|v| { v["clips"]["cut"]["marks"][0]["frame"] = 12.into(); }, "must fall on the clip");
        bad(&|v| { v["sets"]["me"]["clips"]["slash"] = "gone".into(); }, "no clip \"gone\"");
        bad(&|v| { v["poses"]["W"] = serde_json::json!({"a": 0, "b": 0}); }, "same name in capitals");
        bad(&|v| { v["version"] = 2.into(); }, "version must be 1");
    }
}
