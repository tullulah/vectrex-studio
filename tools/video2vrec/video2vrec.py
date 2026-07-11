#!/usr/bin/env python3
"""
video2vrec — convert a raster video into a Vectrex .vrec vector recording.

The .vrec is played back on a Vectrex (or in Vectrex Studio's emulator) via the
DRAW_RECORDING(name, x, y, scale, frame) VPy builtin. See docs — same format the
IDE's vector recorder produces.

Two tracing modes:
  --mode silhouette   Best for binary/shadow-art clips (Bad Apple): threshold to
                      black/white, trace the OUTLINE of each filled region.
  --mode edges        Best for line-art / Flash cartoons with black outlines
                      (The Demented Cartoon Movie): detect dark strokes and trace
                      their contours. (Outline of the ink, not centerline — a
                      later refinement could skeletonize for true centerlines.)

Pipeline per frame: extract → grayscale → threshold → findContours →
approxPolyDP (Ramer-Douglas-Peucker simplify) → budget cap → map to Vectrex
space (-127..127, Y up) → segments. Frames are decimated to the target fps.

Usage:
  python video2vrec.py IN.mp4 OUT.vrec [options]

Requires: numpy, opencv (headless), ffmpeg on PATH.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

import cv2
import numpy as np


def extract_frames(video_path, fps, tmpdir, max_frames=None):
    """Use ffmpeg to dump `fps` frames/sec as PNGs into tmpdir; return sorted paths."""
    pattern = os.path.join(tmpdir, "f_%05d.png")
    vf = f"fps={fps}"
    cmd = ["ffmpeg", "-y", "-i", video_path, "-vf", vf]
    if max_frames:
        cmd += ["-frames:v", str(max_frames)]
    cmd += [pattern]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    files = sorted(
        os.path.join(tmpdir, f) for f in os.listdir(tmpdir) if f.startswith("f_")
    )
    return files


def frame_to_contours(gray, mode, thresh, invert):
    """Return a list of contours (each an Nx2 int array) for one grayscale frame."""
    if mode == "silhouette":
        # Binary: foreground = the filled shapes. Bad Apple = white shapes on
        # black (or vice-versa) — `invert` flips which side is "ink".
        _, bw = cv2.threshold(gray, thresh, 255, cv2.THRESH_BINARY)
        if invert:
            bw = cv2.bitwise_not(bw)
    else:  # edges: ink = dark strokes (the black outlines of the cartoon)
        _, bw = cv2.threshold(gray, thresh, 255, cv2.THRESH_BINARY_INV)
        if invert:
            bw = cv2.bitwise_not(bw)
    contours, _ = cv2.findContours(bw, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    return contours


def simplify(contour, epsilon):
    """Ramer-Douglas-Peucker simplification. `epsilon` in pixels."""
    return cv2.approxPolyDP(contour, epsilon, closed=True).reshape(-1, 2)


def map_point(px, py, w, h):
    """Pixel (px,py) → Vectrex space (-127..127, Y up, centred, aspect-fit)."""
    scale = min(254.0 / w, 254.0 / h)  # fit the larger dimension into ±127
    x = (px - w / 2.0) * scale
    y = -(py - h / 2.0) * scale  # flip Y (screen down → Vectrex up)
    return int(max(-127, min(127, round(x)))), int(max(-127, min(127, round(y))))


def on_same_border(p0, p1, w, h, margin):
    """True if BOTH endpoints hug the SAME frame edge (a frame-border artifact:
    a shape touching the edge makes findContours run along the boundary)."""
    (x0, y0), (x1, y1) = p0, p1
    left = x0 <= margin and x1 <= margin
    right = x0 >= w - 1 - margin and x1 >= w - 1 - margin
    top = y0 <= margin and y1 <= margin
    bottom = y0 >= h - 1 - margin and y1 >= h - 1 - margin
    return left or right or top or bottom


def build_frame(gray, args):
    """One frame → list of {x0,y0,x1,y1,i} segments, honouring the budget."""
    # Optional crop (remove a letterbox / on-screen border) BEFORE tracing.
    if args.crop > 0:
        c = args.crop
        gray = gray[c:gray.shape[0] - c, c:gray.shape[1] - c]
    h, w = gray.shape
    contours = frame_to_contours(gray, args.mode, args.threshold, args.invert)
    # Largest contours first (drop tiny noise / stay within budget on the big shapes).
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    segs = []
    for c in contours:
        if cv2.contourArea(c) < args.min_area:
            continue
        pts = simplify(c, args.epsilon)
        if len(pts) < 2:
            continue
        # Closed contour: connect each vertex to the next, last back to first.
        n = len(pts)
        for i in range(n):
            p0 = pts[i]
            p1 = pts[(i + 1) % n]
            # Drop segments that run along the frame border (screen-edge artifact).
            if args.border_margin >= 0 and on_same_border(p0, p1, w, h, args.border_margin):
                continue
            x0, y0 = map_point(p0[0], p0[1], w, h)
            x1, y1 = map_point(p1[0], p1[1], w, h)
            if x0 == x1 and y0 == y1:
                continue  # skip degenerate
            segs.append({"x0": x0, "y0": y0, "x1": x1, "y1": y1, "i": args.intensity})
            if len(segs) >= args.budget:
                return segs  # hit the per-frame vector budget
    return segs


def main():
    ap = argparse.ArgumentParser(description="Convert a video to a Vectrex .vrec")
    ap.add_argument("input", help="input video (mp4/gif/…)")
    ap.add_argument("output", help="output .vrec")
    ap.add_argument("--name", default=None, help="recording name (default: from output)")
    ap.add_argument("--mode", choices=["silhouette", "edges"], default="silhouette")
    ap.add_argument("--fps", type=int, default=15, help="playback/capture fps (default 15)")
    ap.add_argument("--threshold", type=int, default=128, help="binarize threshold 0-255")
    ap.add_argument("--invert", action="store_true", help="flip ink/background")
    ap.add_argument("--epsilon", type=float, default=2.0,
                    help="RDP simplify strength in px (higher = fewer vertices)")
    ap.add_argument("--budget", type=int, default=200,
                    help="max segments per frame (Vectrex vector budget)")
    ap.add_argument("--min-area", type=float, default=25.0,
                    help="drop contours smaller than this area (px^2)")
    ap.add_argument("--intensity", type=int, default=95, help="beam intensity 0-127")
    ap.add_argument("--crop", type=int, default=0,
                    help="crop N px off every side before tracing (kills letterbox / on-screen frame)")
    ap.add_argument("--border-margin", type=int, default=2,
                    help="drop contour segments running along the frame edge within N px "
                         "(removes the screen-border artifact); -1 to disable")
    ap.add_argument("--max-frames", type=int, default=None, help="limit frames (for testing)")
    args = ap.parse_args()

    name = args.name or os.path.splitext(os.path.basename(args.output))[0]

    with tempfile.TemporaryDirectory() as tmp:
        print(f"[1/3] extracting frames @ {args.fps} fps…", file=sys.stderr)
        files = extract_frames(args.input, args.fps, tmp, args.max_frames)
        if not files:
            print("ERROR: ffmpeg produced no frames", file=sys.stderr)
            sys.exit(1)
        print(f"      {len(files)} frames", file=sys.stderr)

        print(f"[2/3] tracing ({args.mode}, budget {args.budget})…", file=sys.stderr)
        frames = []
        seg_counts = []
        for i, fp in enumerate(files):
            img = cv2.imread(fp, cv2.IMREAD_GRAYSCALE)
            segs = build_frame(img, args)
            frames.append({"segments": segs})
            seg_counts.append(len(segs))
            if (i + 1) % 50 == 0:
                print(f"      {i+1}/{len(files)}", file=sys.stderr)

        vrec = {
            "version": "1.0",
            "name": name,
            "fps": args.fps,
            "frames": frames,
        }
        with open(args.output, "w") as f:
            json.dump(vrec, f)

    avg = sum(seg_counts) / len(seg_counts)
    print(f"[3/3] wrote {args.output}", file=sys.stderr)
    print(f"      frames={len(frames)}  segs/frame: min={min(seg_counts)} "
          f"avg={avg:.0f} max={max(seg_counts)}  (budget {args.budget})", file=sys.stderr)
    if max(seg_counts) >= args.budget:
        print("      NOTE: some frames hit the budget — raise --epsilon to simplify "
              "more, or --budget if the Vectrex can handle it.", file=sys.stderr)


if __name__ == "__main__":
    main()
