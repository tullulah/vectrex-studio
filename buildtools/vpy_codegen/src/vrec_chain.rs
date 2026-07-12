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

#[cfg(test)]
mod tests {
    use super::*;

    fn seg(x0: i32, y0: i32, x1: i32, y1: i32, i: i32) -> Segment {
        Segment { x0, y0, x1, y1, i }
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
