#!/usr/bin/env python3
"""
preview_frame — render ONE frame's trace next to the original, to tune params.

Extracts frame at time T from a video, traces it with the given mode/params (the
same pipeline as video2vrec), and writes a side-by-side PNG: original | traced
(white lines on black, exactly how the Vectrex would draw it). Also prints the
segment count so you can dial in epsilon/budget/threshold before a full convert.

Usage:
  preview_frame.py VIDEO OUT.png --time 6.0 --mode duotone [tracer opts…]
"""
import argparse
import subprocess
import sys
import tempfile
import os

import cv2
import numpy as np

import video2vrec as v  # reuse the exact tracing pipeline


# ffmpeg binary: env override (Electron passes the bundled ffmpeg-static path)
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out", help="output comparison PNG")
    ap.add_argument("--time", type=float, default=0.0, help="timestamp (seconds)")
    ap.add_argument("--mode", choices=["silhouette", "edges", "duotone", "canny"], default="edges")
    ap.add_argument("--threshold", type=int, default=128)
    ap.add_argument("--dark", type=int, default=60)
    ap.add_argument("--light", type=int, default=200)
    ap.add_argument("--canny-lo", type=int, default=60)
    ap.add_argument("--canny-hi", type=int, default=160)
    ap.add_argument("--invert", action="store_true")
    ap.add_argument("--epsilon", type=float, default=2.0)
    ap.add_argument("--budget", type=int, default=250)
    ap.add_argument("--min-area", type=float, default=25.0)
    ap.add_argument("--intensity", type=int, default=95)
    ap.add_argument("--crop", type=int, default=0)
    ap.add_argument("--border-margin", type=int, default=2)
    ap.add_argument("--emit", choices=["png", "json"], default="png",
                    help="png = side-by-side comparison image; json = {segments, "
                         "width, height, originalPng(base64)} for the IDE editor")
    args = ap.parse_args()

    with tempfile.TemporaryDirectory() as tmp:
        fp = os.path.join(tmp, "frame.png")
        subprocess.run([FFMPEG, "-y", "-ss", str(args.time), "-i", args.video,
                        "-frames:v", "1", fp],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        color = cv2.imread(fp, cv2.IMREAD_COLOR)
        gray = cv2.cvtColor(color, cv2.COLOR_BGR2GRAY)

    segs = v.build_frame(gray, args)  # {x0,y0,x1,y1,i} in Vectrex space (±127, Y up)

    h, w = gray.shape

    if args.emit == "json":
        # Machine-readable for the editor: the traced segments (it renders them in
        # its own Vectrex canvas) + the original frame + the 1-bit B&W MASK the
        # tracer actually sees (so the user can dial the threshold visually).
        import base64, json
        # Recompute the mask with the SAME crop build_frame applied.
        mgray = gray
        if args.crop > 0:
            c = args.crop
            mgray = gray[c:gray.shape[0] - c, c:gray.shape[1] - c]
        mask = v.frame_to_mask(mgray, args.mode, args.threshold, args.invert,
                               args.dark, args.light, args.canny_lo, args.canny_hi)
        ok, png = cv2.imencode(".png", color)
        okm, mpng = cv2.imencode(".png", mask)
        print(json.dumps({
            "segments": segs,
            "width": w, "height": h,
            "originalPng": base64.b64encode(png.tobytes()).decode("ascii") if ok else "",
            "maskPng": base64.b64encode(mpng.tobytes()).decode("ascii") if okm else "",
        }))
        return
    # Render the traced result on a black canvas the same size as the frame.
    traced = np.zeros((h, w, 3), np.uint8)
    scale = min(254.0 / w, 254.0 / h)
    def to_px(x, y):
        return int(round(x / scale + w / 2.0)), int(round(-y / scale + h / 2.0))
    for s in segs:
        cv2.line(traced, to_px(s["x0"], s["y0"]), to_px(s["x1"], s["y1"]),
                 (255, 255, 255), 1, cv2.LINE_AA)

    combo = np.hstack([color, traced])
    cv2.putText(combo, f"{args.mode}  eps={args.epsilon}  segs={len(segs)}",
                (8, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    cv2.imwrite(args.out, combo)
    print(f"{args.mode}: {len(segs)} segs @ t={args.time}s → {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
