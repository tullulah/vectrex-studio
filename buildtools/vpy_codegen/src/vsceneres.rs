//! `.vscene` — a SET put together from `.vmesh` pieces: where each piece stands,
//! how it moves as the player travels, how often it repeats, and which pieces a
//! game switches on and off.
//!
//! A `.vmesh` is a shape (since version 2 also a room's lines and occluders). A
//! scene is the arrangement over time: the ribs of a tunnel coming at you every
//! 2000 units, two mountain ranges sliding by at different speeds as you turn,
//! a floor's stripes, the lights that only show when the alarm is on. The game
//! passes one position each frame (`pos`: how far it has gone along x, y, z) and
//! the scene works out where every piece is.
//!
//! ```json
//! { "name": "tunnel",
//!   "fog": {"full": 3000, "gone": 17500},
//!   "groups": ["alarm"],
//!   "items": [
//!     { "name": "ribs", "mesh": "rib", "at": {"z": 600}, "follow": {"z": -1},
//!       "repeat": {"axis": "z", "step": 2000, "count": 9} },
//!     { "name": "panels", "mesh": ["panel_low", "panel_high"], "at": {"z": 600},
//!       "follow": {"z": -1}, "repeat": {"axis": "z", "step": 2000, "count": 9},
//!       "window": {"max": 10999}, "br": 75 },
//!     { "mesh": "edges", "fog": false },
//!     { "mesh": "red_lights", "group": "alarm" } ] }
//! ```
//!
//! - `at`: where the piece stands (x, y, z; missing = 0).
//! - `follow`: how far it moves per unit of `pos`, per axis. `-1` on z: it comes
//!   at you as you advance; `0.9167` on x: a far range that slides by almost as
//!   fast as you turn, so it seems to move only a little. Fractions are kept to
//!   1/65536.
//! - `repeat`: `count` copies `step` apart along `axis`. The copies wrap with the
//!   movement, so there are always `count` of them starting at `at`: the first
//!   one sits within one `step` past `at`. With several meshes (`mesh` a list),
//!   copy n uses mesh n mod the list's length, n counted along the WHOLE run so
//!   the pattern stays put as it scrolls (alternate tunnel bays).
//! - `window`: a copy is drawn only while its z in the world (after `place`)
//!   is within min..max: the near bays only, nothing behind the camera.
//! - `br`: percent of the brightness the scene is drawn at (default 100).
//! - `fog`: how the scene's fog (if it has one) fades the piece. `true` (the
//!   default): each line segment by the depth of its middle, as
//!   `vpy3d_set_scenery_fog` does, so a long line dims away. `"whole"`: each copy
//!   as one, by the depth of its `at`, and a copy faded below brightness 4 is
//!   skipped altogether (a tunnel rib that dims evenly). `false`: not at all.
//!   Per segment fades scenery lines only; "whole" dims the copy's faces too.
//! - `group`: the piece is drawn only when the game sets that group's bit;
//!   `"!name"` the other way round. Up to 32 groups, bit = position in `groups`.
//!
//! Items are drawn in the order listed, each repeat from `at` outwards, and an
//! item's occluders hide only what is drawn after it: list the near pieces first.
//!
//! Binary layout, little-endian throughout:
//! ```text
//!   0  4  magic "VSCN"
//!   4  1  version (1)
//!   5  1  mesh count (the header's mesh table)
//!   6  2  item count
//!   8  4  fog full_until, i32   (both 0: no fog)
//!  12  4  fog gone_at, i32
//!  16  .. items:
//!          u8  flags  bit0 repeat, bit1 no fog, bit2 window, bit3 group negated,
//!                     bit4 fog by the whole copy
//!          u8  group  (255: always drawn)
//!          u8  brightness percent (1..100)
//!          u8  repeat axis (0 x, 1 y, 2 z)
//!          i32 at x, y, z
//!          i32 follow x, y, z   (Q16: 65536 = 1)
//!          i32 repeat step      (> 0 with a repeat)
//!          u8  repeat count     (1..255; 1 without a repeat)
//!          i32 window min, max
//!          u8  mesh count (1..255), then that many u8 indices into the mesh table
//! ```
//!
//! The mesh table is not in the image: the C header lists the `.vmesh` arrays
//! (`<NAME>_vscene_meshes[]`, as a `.vanim` lists its `.vec` sprites) and the
//! game hands both to `vpy3d_load_scene`. Meshes live in `assets/meshes/`, next
//! to the scene's own folder.

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::path::Path;

pub const VSCENE_MAGIC: &[u8; 4] = b"VSCN";
pub const VSCENE_VERSION: u8 = 1;
/// The runtime keeps a scene's meshes in a fixed array of this size by default
/// (VPY3D_SCENE_MESHES in vpy3d.h).
pub const VSCENE_MAX_MESHES: usize = 16;
/// How far a piece may stand from the origin: the same bound as a mesh's scenery.
pub const VSCENE_LIMIT: f64 = 1_000_000.0;

#[derive(Debug, Default, Deserialize)]
pub struct VSceneVec {
    #[serde(default)]
    pub x: f64,
    #[serde(default)]
    pub y: f64,
    #[serde(default)]
    pub z: f64,
}

#[derive(Debug, Deserialize)]
pub struct VSceneFog {
    pub full: i64,
    pub gone: i64,
}

#[derive(Debug, Deserialize)]
pub struct VSceneRepeat {
    #[serde(default = "default_axis")]
    pub axis: String,
    pub step: i64,
    pub count: i64,
}

#[derive(Debug, Deserialize)]
pub struct VSceneWindow {
    #[serde(default)]
    pub min: Option<i64>,
    #[serde(default)]
    pub max: Option<i64>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum VSceneMeshes {
    One(String),
    Many(Vec<String>),
}

/// `true`, `false` or `"whole"`.
#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum VSceneFogMode {
    On(bool),
    Named(String),
}
impl Default for VSceneFogMode {
    fn default() -> Self { VSceneFogMode::On(true) }
}

#[derive(Debug, Deserialize)]
pub struct VSceneItem {
    #[serde(default)]
    pub name: Option<String>,
    pub mesh: VSceneMeshes,
    #[serde(default)]
    pub at: VSceneVec,
    #[serde(default)]
    pub follow: VSceneVec,
    #[serde(default)]
    pub repeat: Option<VSceneRepeat>,
    #[serde(default)]
    pub window: Option<VSceneWindow>,
    #[serde(default)]
    pub br: Option<i64>,
    #[serde(default)]
    pub fog: VSceneFogMode,
    #[serde(default)]
    pub group: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct VSceneResource {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub fog: Option<VSceneFog>,
    #[serde(default)]
    pub groups: Vec<String>,
    #[serde(default)]
    pub items: Vec<VSceneItem>,
}

fn default_axis() -> String { "z".to_string() }

impl VSceneResource {
    pub fn load(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("read {}", path.display()))?;
        serde_json::from_str(&text).with_context(|| format!("parse {}", path.display()))
    }
}

/// A compiled scene: the image, and the meshes its table lists, in order.
pub struct VSceneCompiled {
    pub bytes: Vec<u8>,
    pub meshes: Vec<String>,
}

fn q16(v: f64, what: &str) -> Result<i32> {
    let q = (v * 65536.0).round();
    if !q.is_finite() || q.abs() > 64.0 * 65536.0 {
        bail!("{what}: {v} is out of range (-64..64)");
    }
    Ok(q as i32)
}

fn coord(v: f64, what: &str) -> Result<i32> {
    if v.fract() != 0.0 || v.abs() > VSCENE_LIMIT {
        bail!("{what}: {v} must be a whole number within +-{VSCENE_LIMIT}");
    }
    Ok(v as i32)
}

/// Compile a `.vscene`. Every mesh it names must exist as
/// `<scene dir>/../meshes/<name>.vmesh`.
pub fn compile_vscene_file_to_bytes(path: &Path) -> Result<VSceneCompiled> {
    let r = VSceneResource::load(path)?;
    let meshes_dir = path.parent().unwrap_or(Path::new(".")).join("..").join("meshes");
    compile_vscene(&r, |name| meshes_dir.join(format!("{name}.vmesh")).is_file())
}

pub fn compile_vscene(r: &VSceneResource, mesh_exists: impl Fn(&str) -> bool) -> Result<VSceneCompiled> {
    if r.items.is_empty() {
        bail!("a scene needs at least one item");
    }
    if r.items.len() > u16::MAX as usize {
        bail!("too many items ({})", r.items.len());
    }
    if r.groups.len() > 32 {
        bail!("at most 32 groups ({} given)", r.groups.len());
    }
    for (i, g) in r.groups.iter().enumerate() {
        if g.is_empty() || g.starts_with('!') {
            bail!("group {i}: a name, not empty and not starting with '!'");
        }
        if r.groups[..i].contains(g) {
            bail!("group \"{g}\" is listed twice");
        }
    }
    let (full, gone) = match &r.fog {
        None => (0i64, 0i64),
        Some(f) => {
            if f.full < 0 || f.gone <= f.full || f.gone > i32::MAX as i64 {
                bail!("fog: need 0 <= full < gone (full {}, gone {})", f.full, f.gone);
            }
            (f.full, f.gone)
        }
    };

    let mut table: Vec<String> = Vec::new();
    let mut items = Vec::new();
    for (i, it) in r.items.iter().enumerate() {
        let what = match &it.name { Some(n) => format!("item {i} ({n})"), None => format!("item {i}") };
        let names: Vec<String> = match &it.mesh {
            VSceneMeshes::One(s) => vec![s.clone()],
            VSceneMeshes::Many(v) => v.clone(),
        };
        if names.is_empty() || names.len() > 255 {
            bail!("{what}: mesh must name 1 to 255 meshes");
        }
        if names.len() > 1 && it.repeat.is_none() {
            bail!("{what}: several meshes take turns along a repeat; without one, name a single mesh");
        }
        let mut idx = Vec::new();
        for n in &names {
            if n.is_empty() || n.contains(['/', '\\']) || n.ends_with(".vmesh") {
                bail!("{what}: mesh \"{n}\" must be the name of a .vmesh in assets/meshes, without the extension");
            }
            if !mesh_exists(n) {
                bail!("{what}: mesh \"{n}\" does not exist (assets/meshes/{n}.vmesh)");
            }
            let k = match table.iter().position(|t| t == n) {
                Some(k) => k,
                None => { table.push(n.clone()); table.len() - 1 }
            };
            idx.push(k as u8);
        }
        let mut flags = 0u8;
        let (axis, step, count) = match &it.repeat {
            None => (2u8, 0i32, 1u8),
            Some(rp) => {
                flags |= 1;
                let axis = match rp.axis.as_str() { "x" => 0, "y" => 1, "z" => 2,
                    a => bail!("{what}: repeat axis \"{a}\" (x, y or z)") };
                if rp.step <= 0 || rp.step > VSCENE_LIMIT as i64 {
                    bail!("{what}: repeat step must be 1..{VSCENE_LIMIT}");
                }
                if !(1..=255).contains(&rp.count) {
                    bail!("{what}: repeat count must be 1..255");
                }
                (axis, rp.step as i32, rp.count as u8)
            }
        };
        match &it.fog {
            VSceneFogMode::On(true) => {}
            VSceneFogMode::On(false) => flags |= 2,
            VSceneFogMode::Named(m) if m == "whole" => flags |= 16,
            VSceneFogMode::Named(m) => bail!("{what}: fog is true, false or \"whole\" (not \"{m}\")"),
        }
        let (wmin, wmax) = match &it.window {
            None => (i32::MIN, i32::MAX),
            Some(w) => {
                flags |= 4;
                let lo = w.min.unwrap_or(i32::MIN as i64);
                let hi = w.max.unwrap_or(i32::MAX as i64);
                if lo > hi || lo < i32::MIN as i64 || hi > i32::MAX as i64 {
                    bail!("{what}: window needs min <= max");
                }
                (lo as i32, hi as i32)
            }
        };
        let group = match &it.group {
            None => 255u8,
            Some(g) => {
                let (neg, name) = match g.strip_prefix('!') { Some(n) => (true, n), None => (false, g.as_str()) };
                if neg { flags |= 8; }
                match r.groups.iter().position(|x| x == name) {
                    Some(k) => k as u8,
                    None => bail!("{what}: group \"{name}\" is not in the scene's groups"),
                }
            }
        };
        let br = it.br.unwrap_or(100);
        if !(1..=100).contains(&br) {
            bail!("{what}: br is a percent, 1..100");
        }
        let at = [coord(it.at.x, &format!("{what} at.x"))?, coord(it.at.y, &format!("{what} at.y"))?,
                  coord(it.at.z, &format!("{what} at.z"))?];
        let follow = [q16(it.follow.x, &format!("{what} follow.x"))?, q16(it.follow.y, &format!("{what} follow.y"))?,
                      q16(it.follow.z, &format!("{what} follow.z"))?];

        let mut b = vec![flags, group, br as u8, axis];
        for v in at.iter().chain(follow.iter()) { b.extend_from_slice(&v.to_le_bytes()); }
        b.extend_from_slice(&step.to_le_bytes());
        b.push(count);
        b.extend_from_slice(&wmin.to_le_bytes());
        b.extend_from_slice(&wmax.to_le_bytes());
        b.push(idx.len() as u8);
        b.extend_from_slice(&idx);
        items.push(b);
    }
    if table.len() > VSCENE_MAX_MESHES {
        bail!("a scene may use at most {VSCENE_MAX_MESHES} different meshes ({} used)", table.len());
    }

    let mut out = Vec::new();
    out.extend_from_slice(VSCENE_MAGIC);
    out.push(VSCENE_VERSION);
    out.push(table.len() as u8);
    out.extend_from_slice(&(r.items.len() as u16).to_le_bytes());
    out.extend_from_slice(&(full as i32).to_le_bytes());
    out.extend_from_slice(&(gone as i32).to_le_bytes());
    for b in items { out.extend_from_slice(&b); }
    Ok(VSceneCompiled { bytes: out, meshes: table })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn compile(json: &str) -> Result<VSceneCompiled> {
        let r: VSceneResource = serde_json::from_str(json)?;
        compile_vscene(&r, |n| n != "missing")
    }

    #[test]
    fn a_repeat_with_two_meshes_and_a_window() {
        let c = compile(r#"{"fog":{"full":3000,"gone":17500},"groups":["alarm"],"items":[
            {"mesh":"rib","at":{"z":600},"follow":{"z":-1},"repeat":{"step":2000,"count":9}},
            {"mesh":["low","high"],"at":{"z":600},"follow":{"x":0.5,"z":-1},
             "repeat":{"axis":"z","step":2000,"count":9},"window":{"max":10999},"br":75,"group":"!alarm"},
            {"mesh":"rib","fog":false},{"mesh":"rib","fog":"whole"}]}"#).unwrap();
        let b = &c.bytes;
        assert_eq!(&b[0..4], VSCENE_MAGIC);
        assert_eq!(b[4], VSCENE_VERSION);
        assert_eq!(c.meshes, vec!["rib", "low", "high"]);
        assert_eq!(b[5], 3);
        assert_eq!(u16::from_le_bytes([b[6], b[7]]), 4);
        assert_eq!(i32::from_le_bytes([b[8], b[9], b[10], b[11]]), 3000);
        assert_eq!(i32::from_le_bytes([b[12], b[13], b[14], b[15]]), 17500);
        let item = 4 + 24 + 4 + 1 + 8;                        // where the mesh count sits
        let i0 = &b[16..];
        assert_eq!((i0[0], i0[1], i0[2], i0[3]), (1, 255, 100, 2));   // repeat, always, 100%, z
        assert_eq!(i32::from_le_bytes([i0[12], i0[13], i0[14], i0[15]]), 600);
        assert_eq!(i32::from_le_bytes([i0[24], i0[25], i0[26], i0[27]]), -65536);
        assert_eq!(i32::from_le_bytes([i0[28], i0[29], i0[30], i0[31]]), 2000);
        assert_eq!(i0[32], 9);
        assert_eq!((i0[item], i0[item + 1]), (1, 0));
        let i1 = &i0[item + 2..];
        assert_eq!((i1[0], i1[1], i1[2]), (1 | 4 | 8, 0, 75));       // repeat, window, negated group 0
        assert_eq!(i32::from_le_bytes([i1[16], i1[17], i1[18], i1[19]]), 32768);   // follow x 0.5
        assert_eq!(i32::from_le_bytes([i1[37], i1[38], i1[39], i1[40]]), 10999);   // window max
        assert_eq!((i1[item], i1[item + 1], i1[item + 2]), (2, 1, 2));
        let i2 = &i1[item + 3..];
        assert_eq!((i2[0], i2[32]), (2, 1));                          // no fog, one copy
        let i3 = &i2[item + 2..];
        assert_eq!(i3[0], 16);                                        // fog by the whole copy
        assert_eq!(i3.len(), item + 2);
    }

    #[test]
    fn bad_scenes_are_refused() {
        for (why, json) in [
            ("no items", r#"{"items":[]}"#),
            ("missing mesh", r#"{"items":[{"mesh":"missing"}]}"#),
            ("a path, not a name", r#"{"items":[{"mesh":"../x"}]}"#),
            ("turns without a repeat", r#"{"items":[{"mesh":["a","b"]}]}"#),
            ("zero step", r#"{"items":[{"mesh":"a","repeat":{"step":0,"count":3}}]}"#),
            ("count 0", r#"{"items":[{"mesh":"a","repeat":{"step":10,"count":0}}]}"#),
            ("bad axis", r#"{"items":[{"mesh":"a","repeat":{"axis":"w","step":10,"count":3}}]}"#),
            ("unknown group", r#"{"items":[{"mesh":"a","group":"x"}]}"#),
            ("br over 100", r#"{"items":[{"mesh":"a","br":101}]}"#),
            ("unknown fog mode", r#"{"items":[{"mesh":"a","fog":"thick"}]}"#),
            ("fog backwards", r#"{"fog":{"full":9,"gone":3},"items":[{"mesh":"a"}]}"#),
            ("window backwards", r#"{"items":[{"mesh":"a","window":{"min":5,"max":1}}]}"#),
            ("fractional at", r#"{"items":[{"mesh":"a","at":{"x":0.5}}]}"#),
            ("too far", r#"{"items":[{"mesh":"a","at":{"z":2000000}}]}"#),
        ] {
            assert!(compile(json).is_err(), "{why} must be refused");
        }
        let many: Vec<String> = (0..17).map(|k| format!(r#"{{"mesh":"m{k}"}}"#)).collect();
        assert!(compile(&format!(r#"{{"items":[{}]}}"#, many.join(","))).is_err(), "17 meshes");
    }
}
