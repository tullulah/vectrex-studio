//! Shared .vrec polyline-chaining helper (target-agnostic).
//!
//! A `.vrec` frame stores each line as an independent 5-tuple
//! `(x0, y0, x1, y1, intensity)`. Traced contours (e.g. Bad Apple silhouettes)
//! are closed polylines, so every interior vertex is stored TWICE — the
//! `(x1, y1)` of one segment equals the `(x0, y0)` of the next. That is ~55%
//! redundant and blows past the 32 KB single-bank ROM limit for longer clips.
//!
//! This module folds consecutive segments that share an endpoint AND intensity
//! into a single **chain**: one start point plus one `(dx, dy)` delta per line.
//! A chain of N segments costs ~`4 + 2N` bytes instead of `5N` (break-even at
//! N >= 2). It also draws faster on the Vectrex — one `Reset0Ref` + `Moveto_d`
//! per chain, then continuous `Draw_Line_d` deltas.
//!
//! IMPORTANT: the `.vrec` FILE format is UNCHANGED. Chaining is a compile-time
//! transform over the existing per-segment data. This helper is target-agnostic
//! so the m6809, rp2350 (arm) and pitrex backends can all consume it — only the
//! per-backend byte emitter that turns `Chain`s into ROM bytes differs.

/// One `.vrec` line segment, as read straight from the file (pre-clamp, i32).
/// Endpoint equality for chaining is tested on these RAW coordinates so the
/// decision is independent of any later i8 clamping a backend may apply.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Segment {
    pub x0: i32,
    pub y0: i32,
    pub x1: i32,
    pub y1: i32,
    pub i: i32,
}

/// A chained polyline: a single start point + one delta per line segment, all
/// sharing one intensity. `deltas.len()` is the number of drawn lines.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Chain {
    /// Absolute start point (first vertex of the polyline), raw i32.
    pub start: (i32, i32),
    /// Shared intensity for every line in the chain (raw i32, pre-clamp).
    pub intensity: i32,
    /// One `(dx, dy)` per line segment: `dx = x1 - x0`, `dy = y1 - y0`.
    pub deltas: Vec<(i32, i32)>,
}

/// Fold a frame's ordered segment list into polyline chains.
///
/// Deterministic and ORDER-PRESERVING: segments are walked in file order. A new
/// segment extends the current chain iff its `(x0, y0)` equals the previous
/// segment's `(x1, y1)` and it has the same intensity; otherwise the current
/// chain is closed and a new one begins. Degenerate zero-length segments are
/// kept (they are still explicit lines in the source data).
pub fn chain_frame(segments: &[Segment]) -> Vec<Chain> {
    let mut chains: Vec<Chain> = Vec::new();

    for seg in segments {
        let dx = seg.x1 - seg.x0;
        let dy = seg.y1 - seg.y0;

        // Extend the open chain if this segment continues it (shared endpoint +
        // same intensity). We track the running "pen" position implicitly: the
        // last chain's start plus the sum of its deltas == the previous
        // segment's (x1, y1). Comparing against that avoids storing extra state.
        if let Some(last) = chains.last_mut() {
            let (mut px, mut py) = last.start;
            for (ddx, ddy) in &last.deltas {
                px += ddx;
                py += ddy;
            }
            if px == seg.x0 && py == seg.y0 && last.intensity == seg.i {
                last.deltas.push((dx, dy));
                continue;
            }
        }

        // Otherwise start a new chain at this segment's start point.
        chains.push(Chain {
            start: (seg.x0, seg.y0),
            intensity: seg.i,
            deltas: vec![(dx, dy)],
        });
    }

    chains
}

// ============================================================
// Standalone precompiled binary `.vrb` format
// ============================================================
//
// The SAME polyline-chained layout the ARM/m6809 backends bake into ROM, but as
// a self-describing standalone file — so a precompiled `.vrb` on the SD is read
// identically by the IDE emulator and (later) the RP2350 firmware. Streamable:
// the frame offset table lets a reader seek to any frame without holding the
// whole file. Little-endian throughout.
//
//   [0]  magic         "VRB1"        (4 bytes)
//   [4]  fps           u16
//   [6]  frame_count   u16
//   [8]  offset table  u32 × frame_count  (byte offset from file start → frame)
//   ...  per frame:
//          chain_count u16
//          per chain:  start_x i8, start_y i8, intensity u8, seg_count u8,
//                      then seg_count × (dx i8, dy i8)

const VRB_MAX_DELTAS_PER_CHAIN: usize = 255;

#[derive(serde::Deserialize)]
struct VrbSeg { x0: i32, y0: i32, x1: i32, y1: i32, i: i32 }
#[derive(serde::Deserialize)]
struct VrbFrame { #[serde(default)] segments: Vec<VrbSeg> }
#[derive(serde::Deserialize)]
struct VrbDoc {
    #[serde(default)] fps: f64,
    #[serde(default)] frames: Vec<VrbFrame>,
}

/// Squared perpendicular distance from point `p` to the line through `a`,`b`.
fn perp_dist_sq(p: (i32, i32), a: (i32, i32), b: (i32, i32)) -> i64 {
    let (px, py) = (p.0 as i64, p.1 as i64);
    let (ax, ay) = (a.0 as i64, a.1 as i64);
    let (bx, by) = (b.0 as i64, b.1 as i64);
    let (dx, dy) = (bx - ax, by - ay);
    if dx == 0 && dy == 0 {
        let (ex, ey) = (px - ax, py - ay);
        return ex * ex + ey * ey;
    }
    let num = (dy * (px - ax) - dx * (py - ay)).abs();
    (num * num) / (dx * dx + dy * dy)
}

/// Douglas-Peucker polyline simplification (keeps both endpoints). Drops points
/// that deviate less than `eps` (eps² passed in) — invisible once the preview is
/// scaled down, and each dropped point is one fewer vector to draw.
fn douglas_peucker(pts: &[(i32, i32)], eps_sq: i64) -> Vec<(i32, i32)> {
    if pts.len() <= 2 {
        return pts.to_vec();
    }
    let (a, b) = (pts[0], *pts.last().unwrap());
    let mut max_d = -1i64;
    let mut idx = 0;
    for i in 1..pts.len() - 1 {
        let d = perp_dist_sq(pts[i], a, b);
        if d > max_d {
            max_d = d;
            idx = i;
        }
    }
    if max_d > eps_sq {
        let mut left = douglas_peucker(&pts[..=idx], eps_sq);
        let right = douglas_peucker(&pts[idx..], eps_sq);
        left.pop(); // drop the shared join point
        left.extend(right);
        left
    } else {
        vec![a, b]
    }
}

/// Split a delta whose |dx| or |dy| exceeds 127 into ≤127-unit steps along the
/// line (simplification can merge points into a delta too big for one i8).
fn split_delta(dx: i32, dy: i32, out: &mut Vec<(i32, i32)>) {
    let steps = (dx.abs().max(dy.abs()) + 126) / 127;
    if steps <= 1 {
        out.push((dx, dy));
        return;
    }
    let (mut ax, mut ay) = (0i32, 0i32);
    for s in 1..=steps {
        let (tx, ty) = (dx * s / steps, dy * s / steps);
        out.push((tx - ax, ty - ay));
        ax = tx;
        ay = ty;
    }
}

/// Compile a `.vrec` JSON string into the standalone binary `.vrb` blob.
/// `simplify_eps` runs Douglas-Peucker per polyline (0 = off; ~2 suits previews).
pub fn compile_vrec_json_to_binary(json: &str, simplify_eps: i32) -> Result<Vec<u8>, String> {
    let doc: VrbDoc = serde_json::from_str(json).map_err(|e| format!("bad .vrec JSON: {e}"))?;
    let frame_count = doc.frames.len();
    if frame_count > u16::MAX as usize {
        return Err(format!("too many frames: {frame_count} (max {})", u16::MAX));
    }
    let clamp8 = |v: i32| v.clamp(-127, 127) as i8;
    let eps_sq = (simplify_eps.max(0) as i64) * (simplify_eps.max(0) as i64);

    // Serialize each frame's payload first, then assemble with the offset table.
    let mut frame_blobs: Vec<Vec<u8>> = Vec::with_capacity(frame_count);
    for frame in &doc.frames {
        let segs: Vec<Segment> = frame.segments.iter()
            .map(|s| Segment { x0: s.x0, y0: s.y0, x1: s.x1, y1: s.y1, i: s.i })
            .collect();
        let chains = chain_frame(&segs);
        let mut emitted: Vec<(i32, i32, i32, Vec<(i32, i32)>)> = Vec::new();
        for c in &chains {
            // Reconstruct the polyline, simplify, re-delta, split any long delta.
            let mut pts: Vec<(i32, i32)> = Vec::with_capacity(c.deltas.len() + 1);
            pts.push(c.start);
            let (mut x, mut y) = c.start;
            for (dx, dy) in &c.deltas {
                x += dx;
                y += dy;
                pts.push((x, y));
            }
            let pts = if simplify_eps > 0 { douglas_peucker(&pts, eps_sq) } else { pts };
            if pts.len() < 2 {
                continue;
            }
            let start = pts[0];
            let mut deltas: Vec<(i32, i32)> = Vec::new();
            for w in pts.windows(2) {
                split_delta(w[1].0 - w[0].0, w[1].1 - w[0].1, &mut deltas);
            }
            // Split chains > 255 deltas so seg_count fits one byte (re-anchor).
            if deltas.len() <= VRB_MAX_DELTAS_PER_CHAIN {
                emitted.push((start.0, start.1, c.intensity, deltas));
            } else {
                let (mut px, mut py) = start;
                for part in deltas.chunks(VRB_MAX_DELTAS_PER_CHAIN) {
                    emitted.push((px, py, c.intensity, part.to_vec()));
                    for (dx, dy) in part {
                        px += dx;
                        py += dy;
                    }
                }
            }
        }
        let mut blob = Vec::new();
        blob.extend_from_slice(&(emitted.len() as u16).to_le_bytes());
        for (sx, sy, inten, deltas) in &emitted {
            blob.push(clamp8(*sx) as u8);
            blob.push(clamp8(*sy) as u8);
            blob.push((*inten).clamp(0, 127) as u8);
            blob.push(deltas.len() as u8);
            for (dx, dy) in deltas {
                blob.push(clamp8(*dx) as u8);
                blob.push(clamp8(*dy) as u8);
            }
        }
        frame_blobs.push(blob);
    }

    let data_start = 8 + 4 * frame_count; // header + offset table
    let mut out = Vec::new();
    out.extend_from_slice(b"VRB1");
    out.extend_from_slice(&(doc.fps.round().clamp(1.0, 255.0) as u16).to_le_bytes());
    out.extend_from_slice(&(frame_count as u16).to_le_bytes());
    let mut off = data_start as u32;
    for blob in &frame_blobs {
        out.extend_from_slice(&off.to_le_bytes());
        off += blob.len() as u32;
    }
    for blob in &frame_blobs {
        out.extend_from_slice(blob);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(x0: i32, y0: i32, x1: i32, y1: i32, i: i32) -> Segment {
        Segment { x0, y0, x1, y1, i }
    }

    /// The binary `.vrb` blob has the right header, offset table, and a frame
    /// whose closed square folds to one 4-delta chain.
    #[test]
    fn vrb_binary_header_and_frame() {
        let json = r#"{"fps":15,"frames":[{"segments":[
            {"x0":-40,"y0":-40,"x1":40,"y1":-40,"i":90},
            {"x0":40,"y0":-40,"x1":40,"y1":40,"i":90},
            {"x0":40,"y0":40,"x1":-40,"y1":40,"i":90},
            {"x0":-40,"y0":40,"x1":-40,"y1":-40,"i":90}
        ]}]}"#;
        let b = compile_vrec_json_to_binary(json, 0).unwrap();
        assert_eq!(&b[0..4], b"VRB1");
        assert_eq!(u16::from_le_bytes([b[4], b[5]]), 15);      // fps
        assert_eq!(u16::from_le_bytes([b[6], b[7]]), 1);       // frame_count
        let off = u32::from_le_bytes([b[8], b[9], b[10], b[11]]) as usize;
        assert_eq!(off, 12);                                   // 8 header + 4 table
        assert_eq!(u16::from_le_bytes([b[off], b[off + 1]]), 1); // chain_count
        // chain header: start (-40,-40), i=90, seg_count=4
        assert_eq!(b[off + 2] as i8, -40);
        assert_eq!(b[off + 3] as i8, -40);
        assert_eq!(b[off + 4], 90);
        assert_eq!(b[off + 5], 4);
    }

    /// A closed square (4 segments, each end == next start, same intensity)
    /// collapses to ONE chain of 4 deltas starting at the first vertex.
    #[test]
    fn closed_square_is_one_chain_of_four() {
        let segs = vec![
            seg(-40, -40, 40, -40, 90), // bottom
            seg(40, -40, 40, 40, 90),   // right
            seg(40, 40, -40, 40, 90),   // top
            seg(-40, 40, -40, -40, 90), // left (closes)
        ];
        let chains = chain_frame(&segs);
        assert_eq!(chains.len(), 1, "closed square must be a single chain");
        let c = &chains[0];
        assert_eq!(c.start, (-40, -40));
        assert_eq!(c.intensity, 90);
        assert_eq!(c.deltas, vec![(80, 0), (0, 80), (-80, 0), (0, -80)]);
    }

    /// Two disjoint segments (no shared endpoint) stay as two 1-delta chains.
    #[test]
    fn two_disjoint_segments_are_two_chains() {
        let segs = vec![
            seg(0, 0, 10, 0, 100),
            seg(50, 50, 60, 50, 100),
        ];
        let chains = chain_frame(&segs);
        assert_eq!(chains.len(), 2);
        assert_eq!(chains[0].start, (0, 0));
        assert_eq!(chains[0].deltas, vec![(10, 0)]);
        assert_eq!(chains[1].start, (50, 50));
        assert_eq!(chains[1].deltas, vec![(10, 0)]);
    }

    /// A shared endpoint but DIFFERENT intensity must break the chain.
    #[test]
    fn intensity_change_breaks_chain() {
        let segs = vec![
            seg(0, 0, 10, 0, 80),
            seg(10, 0, 20, 0, 95), // continues geometrically, but new intensity
        ];
        let chains = chain_frame(&segs);
        assert_eq!(chains.len(), 2);
        assert_eq!(chains[0].intensity, 80);
        assert_eq!(chains[1].intensity, 95);
        assert_eq!(chains[1].start, (10, 0));
    }

    /// An open polyline (3 connected segments) is one chain of 3 deltas.
    #[test]
    fn open_polyline_chains_all_segments() {
        let segs = vec![
            seg(0, 0, 5, 0, 50),
            seg(5, 0, 5, 5, 50),
            seg(5, 5, 0, 5, 50),
        ];
        let chains = chain_frame(&segs);
        assert_eq!(chains.len(), 1);
        assert_eq!(chains[0].deltas.len(), 3);
        assert_eq!(chains[0].start, (0, 0));
    }

    /// Empty frame → no chains.
    #[test]
    fn empty_frame_no_chains() {
        assert!(chain_frame(&[]).is_empty());
    }

    /// Mixed: a closed triangle then a disjoint segment → 2 chains (3 + 1).
    #[test]
    fn mixed_contour_then_disjoint() {
        let segs = vec![
            seg(0, 0, 10, 0, 70),
            seg(10, 0, 5, 8, 70),
            seg(5, 8, 0, 0, 70), // closes triangle
            seg(30, 30, 40, 30, 70), // disjoint
        ];
        let chains = chain_frame(&segs);
        assert_eq!(chains.len(), 2);
        assert_eq!(chains[0].deltas.len(), 3);
        assert_eq!(chains[1].deltas.len(), 1);
        assert_eq!(chains[1].start, (30, 30));
    }
}
