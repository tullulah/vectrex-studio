//! `.vmesh` — a SURFACE mesh: vertices, faces, and how sharp a crease has to be
//! before it stays as a line.
//!
//! WHY A NEW TYPE AND NOT A BIGGER `.vec`. A `.vec` already carries a `z` per
//! point, so it is a 3D format — of wireframe. But hidden-line removal needs
//! FACES, and that is not a field you can bolt onto `.vec` cheaply: it has six
//! readers (the m6809, arm, pitrex backends, libvpy, the level compiler and the
//! editor) and the last time this project grew a format without auditing all of
//! them it cost four days and three unrelated-looking symptoms. `.vmesh` has one
//! reader. It also carries a MAGIC and a VERSION from the start, which `.vec`
//! cannot be given any more.
//!
//! Two ways to author one. Either list the vertices and faces, or give ordered
//! cross-SECTIONS and let the compiler loft them — which is how a hull, a tube
//! or a car body actually gets drawn, and lets a section come straight out of a
//! `.vec` file so the existing editor stays the tool.
//!
//! ```json
//! { "name": "cube", "hard": 45,
//!   "vertices": [ {"x":-100,"y":-100,"z":-100}, ... ],
//!   "faces": [ [0,3,2,1], [4,5,6,7], ... ] }
//!
//! { "name": "hull", "hard": 45, "caps": true,
//!   "sections": [ {"z": -100, "points": [{"x":0,"y":0}, ...]},
//!                 {"z":  100, "vec": "outline.vec", "path": "rib"} ] }
//! ```
//!
//! Binary layout, little-endian throughout:
//! ```text
//!   0  4  magic "VMSH"
//!   4  1  version (1)
//!   5  1  flags — bit0: open, a plate rather than a solid
//!   6  2  hard_cos, Q14 cosine of the crease threshold
//!   8  2  vertex count
//!  10  2  face count
//!  12  2  total face index entries
//!  14  2  reserved, 0
//!  16  .. vertices: x, y, z as i16 each
//!   .. .. faces: u8 count, then that many u16 vertex indices
//! ```
//!
//! Version 2 adds SCENERY, after the faces: lines that are not edges of any face
//! and occluders that are never drawn. A file that uses neither still compiles
//! to version 1, byte for byte, so it loads on every runtime.
//! ```text
//!   .. 2  line count
//!          per line: u8 point count (2..255), u8 brightness percent (1..100),
//!                    u8 flags (bit0: closed, bit1: no fog), then the points as i32 x, y, z
//!   .. 2  occluder count
//!          per occluder: u8 corner count (3..8), then the corners as i32 x, y, z
//! ```
//! Scenery points are i32 because a room is far bigger than a model: a vertex
//! keeps the i16 range.
//!
//! ```json
//! { "name": "throne",
//!   "lines": [ {"points": [{"x":-4600,"y":3800,"z":6500}, ...], "br": 70, "closed": true} ],
//!   "occluders": [ {"points": [ ...3 to 8 corners of a convex solid... ]} ] }
//! ```

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::path::Path;

pub const VMESH_MAGIC: &[u8; 4] = b"VMSH";
pub const VMESH_VERSION: u8 = 1;
/// The version a file with `lines` or `occluders` compiles to.
pub const VMESH_VERSION_SCENERY: u8 = 2;
/// How far a scenery point may sit from the origin.
pub const SCENERY_LIMIT: i64 = 1_000_000;

#[derive(Debug, Deserialize)]
pub struct VMeshPoint {
    pub x: i32,
    pub y: i32,
    #[serde(default)]
    pub z: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct VMeshSection {
    /// Where this section sits along the lofting axis. Ignored for a point that
    /// carries its own `z`.
    #[serde(default)]
    pub z: i32,
    #[serde(default)]
    pub points: Vec<VMeshPoint>,
    /// Take the ring from a `.vec` instead, resolved next to the `.vmesh`.
    #[serde(default)]
    pub vec: Option<String>,
    /// Which path inside that `.vec`; the first visible one if absent.
    #[serde(default)]
    pub path: Option<String>,
}

/// A polyline drawn as it is: not an edge of a face, never culled.
#[derive(Debug, Deserialize)]
pub struct VMeshLine {
    pub points: Vec<VMeshPoint>,
    /// Percent of the brightness the mesh is drawn with.
    #[serde(default)]
    pub br: Option<i64>,
    /// Join the last point back to the first.
    #[serde(default)]
    pub closed: bool,
    /// Faded by the scenery fog (vpy3d_set_scenery_fog). `false` keeps it at its brightness.
    #[serde(default)]
    pub fog: Option<bool>,
}

/// A convex solid by its corners: never drawn, it hides what is drawn after it.
#[derive(Debug, Deserialize)]
pub struct VMeshOccluder {
    pub points: Vec<VMeshPoint>,
}

#[derive(Debug, Deserialize)]
pub struct VMeshResource {
    #[serde(default)]
    pub name: String,
    /// Crease threshold in DEGREES: faces meeting more sharply than this keep
    /// their shared edge. 45 is a sensible default.
    #[serde(default)]
    pub hard: Option<f64>,
    /// Or give the Q14 cosine directly, if you know exactly what you want.
    #[serde(default)]
    pub hard_cos: Option<i32>,
    /// A plate, not a solid: its rim is drawn from either side.
    #[serde(default)]
    pub open: bool,
    /// Close the ends when lofting sections.
    #[serde(default = "default_true")]
    pub caps: bool,
    #[serde(default)]
    pub vertices: Vec<VMeshPoint>,
    #[serde(default)]
    pub faces: Vec<Vec<u16>>,
    #[serde(default)]
    pub sections: Vec<VMeshSection>,
    #[serde(default)]
    pub lines: Vec<VMeshLine>,
    #[serde(default)]
    pub occluders: Vec<VMeshOccluder>,
}

fn default_true() -> bool { true }

impl VMeshResource {
    pub fn load(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("reading {}", path.display()))?;
        let r: VMeshResource = serde_json::from_str(&text)
            .with_context(|| format!("parsing {}", path.display()))?;
        Ok(r)
    }
}

/// Q14 cosine of the crease threshold. 16384 = every edge is a line.
fn hard_cos_q14(r: &VMeshResource) -> i32 {
    if let Some(c) = r.hard_cos {
        return c.clamp(-16384, 16384);
    }
    let deg = r.hard.unwrap_or(45.0);
    ((deg.to_radians().cos()) * 16384.0).round().clamp(-16384.0, 16384.0) as i32
}

/// Resolve a section's ring into (x, y, z) triples.
fn section_ring(s: &VMeshSection, base_dir: &Path) -> Result<Vec<(i32, i32, i32)>> {
    if let Some(vec_file) = &s.vec {
        let p = base_dir.join(vec_file);
        let res = crate::vecres::VecResource::load(&p)
            .with_context(|| format!("loading section .vec {}", p.display()))?;
        let paths = res.visible_paths();
        let chosen = match &s.path {
            Some(want) => paths.iter().find(|pp| &pp.name == want).copied(),
            None => paths.first().copied(),
        };
        let Some(vp) = chosen else {
            bail!("{}: no path named {:?}", p.display(), s.path);
        };
        if vp.points.len() < 3 {
            bail!("{}: path {:?} has {} points, a ring needs 3",
                  p.display(), vp.name, vp.points.len());
        }
        return Ok(vp.points.iter()
            .map(|pt| (pt.x as i32, pt.y as i32, pt.z.map(|v| v as i32).unwrap_or(s.z)))
            .collect());
    }
    if s.points.len() < 3 {
        bail!("a section needs at least 3 points (got {})", s.points.len());
    }
    Ok(s.points.iter().map(|p| (p.x, p.y, p.z.unwrap_or(s.z))).collect())
}

/// Turn ordered sections into vertices + quad faces, with optional end caps.
/// Every section must have the same number of points: point k of one ring joins
/// point k of the next, and there is no sane guess when the counts differ.
fn loft(r: &VMeshResource, base_dir: &Path)
    -> Result<(Vec<(i32, i32, i32)>, Vec<Vec<u16>>)>
{
    let rings: Vec<Vec<(i32, i32, i32)>> = r.sections.iter()
        .map(|s| section_ring(s, base_dir))
        .collect::<Result<_>>()?;
    if rings.len() < 2 {
        bail!("lofting needs at least 2 sections (got {})", rings.len());
    }
    let n = rings[0].len();
    for (i, ring) in rings.iter().enumerate() {
        if ring.len() != n {
            bail!("section {} has {} points but section 0 has {}: \
                   every section must have the same count", i, ring.len(), n);
        }
    }

    let mut verts: Vec<(i32, i32, i32)> = Vec::new();
    for ring in &rings { verts.extend(ring.iter().copied()); }

    let mut faces: Vec<Vec<u16>> = Vec::new();
    for s in 0..rings.len() - 1 {
        let a = (s * n) as u16;
        let b = ((s + 1) * n) as u16;
        for k in 0..n {
            let k2 = ((k + 1) % n) as u16;
            let k = k as u16;
            faces.push(vec![a + k, a + k2, b + k2, b + k]);
        }
    }
    if r.caps {
        let last = ((rings.len() - 1) * n) as u16;
        faces.push((0..n as u16).rev().collect());              /* the near end */
        faces.push((0..n as u16).map(|k| last + k).collect());  /* the far end  */
    }
    Ok((verts, faces))
}

/// Compile a `.vmesh` into its byte image.
pub fn compile_vmesh_file_to_bytes(path: &Path) -> Result<Vec<u8>> {
    let r = VMeshResource::load(path)?;
    let base = path.parent().unwrap_or_else(|| Path::new("."));

    let (verts, faces) = if !r.sections.is_empty() {
        if !r.vertices.is_empty() || !r.faces.is_empty() {
            bail!("a .vmesh gives either `sections` OR `vertices`+`faces`, not both");
        }
        loft(&r, base)?
    } else {
        if r.vertices.is_empty() != r.faces.is_empty() {
            bail!("a .vmesh with `vertices` needs `faces`, and the other way round");
        }
        if r.vertices.is_empty() && r.lines.is_empty() && r.occluders.is_empty() {
            bail!("a .vmesh needs `sections`, `vertices` and `faces`, `lines` or `occluders`");
        }
        (r.vertices.iter().map(|p| (p.x, p.y, p.z.unwrap_or(0))).collect(),
         r.faces.clone())
    };

    if verts.len() > u16::MAX as usize { bail!("{} vertices is too many", verts.len()); }
    for (fi, f) in faces.iter().enumerate() {
        if f.len() < 3 { bail!("face {} has {} vertices, needs 3", fi, f.len()); }
        if f.len() > 255 { bail!("face {} has {} vertices, the count is a byte", fi, f.len()); }
        for &i in f {
            if i as usize >= verts.len() {
                bail!("face {} refers to vertex {} but there are only {}", fi, i, verts.len());
            }
        }
    }
    for (vi, v) in verts.iter().enumerate() {
        for (axis, c) in [("x", v.0), ("y", v.1), ("z", v.2)] {
            if c < i16::MIN as i32 || c > i16::MAX as i32 {
                bail!("vertex {} has {}={}, outside the i16 the format stores", vi, axis, c);
            }
        }
    }

    let scenery = !r.lines.is_empty() || !r.occluders.is_empty();
    let pt = |p: &VMeshPoint, what: &str| -> Result<[i32; 3]> {
        let c = [p.x, p.y, p.z.unwrap_or(0)];
        for v in c {
            if (v as i64).abs() > SCENERY_LIMIT {
                bail!("{} has a coordinate {} beyond ±{}", what, v, SCENERY_LIMIT);
            }
        }
        Ok(c)
    };
    let mut lines: Vec<(u8, u8, Vec<[i32; 3]>)> = Vec::new();
    for (li, l) in r.lines.iter().enumerate() {
        if l.points.len() < 2 || l.points.len() > 255 {
            bail!("line {} has {} points, needs 2 to 255", li, l.points.len());
        }
        let br = l.br.unwrap_or(100);
        if !(1..=100).contains(&br) { bail!("line {} has br {}, needs 1 to 100", li, br); }
        let pts = l.points.iter().map(|p| pt(p, &format!("line {}", li))).collect::<Result<Vec<_>>>()?;
        let flags = (l.closed as u8) | if l.fog == Some(false) { 2 } else { 0 };
        lines.push((br as u8, flags, pts));
    }
    let mut occs: Vec<Vec<[i32; 3]>> = Vec::new();
    for (oi, o) in r.occluders.iter().enumerate() {
        if o.points.len() < 3 || o.points.len() > 8 {
            bail!("occluder {} has {} corners, needs 3 to 8", oi, o.points.len());
        }
        occs.push(o.points.iter().map(|p| pt(p, &format!("occluder {}", oi))).collect::<Result<Vec<_>>>()?);
    }
    if lines.len() > u16::MAX as usize || occs.len() > u16::MAX as usize {
        bail!("too many lines or occluders");
    }

    let idx_total: usize = faces.iter().map(|f| f.len()).sum();
    let mut out = Vec::with_capacity(16 + verts.len() * 6 + faces.len() + idx_total * 2);
    out.extend_from_slice(VMESH_MAGIC);
    out.push(if scenery { VMESH_VERSION_SCENERY } else { VMESH_VERSION });
    out.push(if r.open { 1 } else { 0 });
    out.extend_from_slice(&(hard_cos_q14(&r) as i16).to_le_bytes());
    out.extend_from_slice(&(verts.len() as u16).to_le_bytes());
    out.extend_from_slice(&(faces.len() as u16).to_le_bytes());
    out.extend_from_slice(&(idx_total as u16).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    for v in &verts {
        out.extend_from_slice(&(v.0 as i16).to_le_bytes());
        out.extend_from_slice(&(v.1 as i16).to_le_bytes());
        out.extend_from_slice(&(v.2 as i16).to_le_bytes());
    }
    for f in &faces {
        out.push(f.len() as u8);
        for &i in f { out.extend_from_slice(&i.to_le_bytes()); }
    }
    if scenery {
        let put = |out: &mut Vec<u8>, p: &[i32; 3]| for c in p { out.extend_from_slice(&c.to_le_bytes()); };
        out.extend_from_slice(&(lines.len() as u16).to_le_bytes());
        for (br, flags, pts) in &lines {
            out.push(pts.len() as u8);
            out.push(*br);
            out.push(*flags);
            for p in pts { put(&mut out, p); }
        }
        out.extend_from_slice(&(occs.len() as u16).to_le_bytes());
        for o in &occs {
            out.push(o.len() as u8);
            for p in o { put(&mut out, p); }
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    /// Each case gets its OWN file: cargo runs these in parallel and a shared
    /// temp name means one test compiles another test's JSON.
    fn compile_as(tag: &str, json: &str) -> Result<Vec<u8>> {
        let dir = std::env::temp_dir().join(format!("vmesh_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let p = dir.join(format!("{tag}.vmesh"));
        std::fs::File::create(&p).unwrap().write_all(json.as_bytes()).unwrap();
        compile_vmesh_file_to_bytes(&p)
    }

    #[test]
    fn explicit_cube_header_is_right() {
        let b = compile_as("cube", r#"{"name":"c","hard":45,
            "vertices":[{"x":-1,"y":-1,"z":-1},{"x":1,"y":-1,"z":-1},
                        {"x":1,"y":1,"z":-1},{"x":-1,"y":1,"z":-1}],
            "faces":[[0,3,2,1]]}"#).unwrap();
        assert_eq!(&b[0..4], VMESH_MAGIC);
        assert_eq!(b[4], VMESH_VERSION);
        assert_eq!(u16::from_le_bytes([b[8], b[9]]), 4);    // vertices
        assert_eq!(u16::from_le_bytes([b[10], b[11]]), 1);  // faces
        assert_eq!(u16::from_le_bytes([b[12], b[13]]), 4);  // index entries
        // cos 45 deg in Q14
        assert_eq!(i16::from_le_bytes([b[6], b[7]]), 11585);
    }

    #[test]
    fn loft_makes_a_tube_and_caps_it() {
        // two triangular rings -> 3 side quads + 2 caps
        let b = compile_as("tube", r#"{"name":"t","caps":true,"sections":[
            {"z":-10,"points":[{"x":0,"y":10},{"x":9,"y":-5},{"x":-9,"y":-5}]},
            {"z": 10,"points":[{"x":0,"y":10},{"x":9,"y":-5},{"x":-9,"y":-5}]}]}"#).unwrap();
        assert_eq!(u16::from_le_bytes([b[8], b[9]]), 6);    // 2 rings x 3
        assert_eq!(u16::from_le_bytes([b[10], b[11]]), 5);  // 3 sides + 2 caps
        assert_eq!(u16::from_le_bytes([b[12], b[13]]), 3 * 4 + 2 * 3);
    }

    #[test]
    fn mismatched_sections_are_refused_not_guessed() {
        let e = compile_as("mismatch", r#"{"sections":[
            {"z":0,"points":[{"x":0,"y":0},{"x":1,"y":0},{"x":0,"y":1}]},
            {"z":9,"points":[{"x":0,"y":0},{"x":1,"y":0},{"x":0,"y":1},{"x":1,"y":1}]}]}"#);
        assert!(e.is_err(), "sections with different point counts must be an error");
    }

    #[test]
    fn a_face_index_out_of_range_is_caught() {
        let e = compile_as("badidx", r#"{"vertices":[{"x":0,"y":0,"z":0}],"faces":[[0,1,2]]}"#);
        assert!(e.is_err());
    }

    #[test]
    fn a_plain_mesh_stays_version_1() {
        let b = compile_as("plain", r#"{"vertices":[{"x":0,"y":0,"z":0},{"x":9,"y":0,"z":0},{"x":0,"y":9,"z":0}],
            "faces":[[0,1,2]]}"#).unwrap();
        assert_eq!(b[4], 1);
        assert_eq!(b.len(), 16 + 3 * 6 + 1 + 3 * 2);
    }

    #[test]
    fn scenery_only_compiles_to_version_2() {
        let b = compile_as("scenery", r#"{"name":"room",
            "lines":[{"points":[{"x":-40000,"y":0,"z":5},{"x":40000,"y":0,"z":5},{"x":0,"y":3000}],"br":70,"closed":true,"fog":false}],
            "occluders":[{"points":[{"x":0,"y":0,"z":0},{"x":1,"y":0,"z":0},{"x":0,"y":1,"z":0}]}]}"#).unwrap();
        assert_eq!(b[4], VMESH_VERSION_SCENERY);
        assert_eq!(u16::from_le_bytes([b[8], b[9]]), 0);     // no vertices
        assert_eq!(u16::from_le_bytes([b[10], b[11]]), 0);   // no faces
        let l = &b[16..];
        assert_eq!(u16::from_le_bytes([l[0], l[1]]), 1);     // one line
        assert_eq!((l[2], l[3], l[4]), (3, 70, 3));           // 3 points, 70%, closed + no fog
        assert_eq!(i32::from_le_bytes([l[5], l[6], l[7], l[8]]), -40000);
        let o = &l[5 + 3 * 12..];
        assert_eq!(u16::from_le_bytes([o[0], o[1]]), 1);     // one occluder
        assert_eq!(o[2], 3);
        assert_eq!(o.len(), 3 + 3 * 12);
    }

    #[test]
    fn bad_scenery_is_refused() {
        assert!(compile_as("line1", r#"{"lines":[{"points":[{"x":0,"y":0}]}]}"#).is_err());
        assert!(compile_as("brzero", r#"{"lines":[{"points":[{"x":0,"y":0},{"x":1,"y":0}],"br":0}]}"#).is_err());
        assert!(compile_as("occ2", r#"{"occluders":[{"points":[{"x":0,"y":0},{"x":1,"y":0}]}]}"#).is_err());
        assert!(compile_as("far", r#"{"lines":[{"points":[{"x":0,"y":0},{"x":2000000,"y":0}]}]}"#).is_err());
        assert!(compile_as("empty", r#"{"name":"nothing"}"#).is_err());
    }

    #[test]
    fn both_forms_at_once_is_refused() {
        let e = compile_as("both", r#"{"vertices":[{"x":0,"y":0,"z":0}],"faces":[[0,0,0]],
            "sections":[{"z":0,"points":[{"x":0,"y":0},{"x":1,"y":0},{"x":0,"y":1}]},
                        {"z":1,"points":[{"x":0,"y":0},{"x":1,"y":0},{"x":0,"y":1}]}]}"#);
        assert!(e.is_err());
    }
}
