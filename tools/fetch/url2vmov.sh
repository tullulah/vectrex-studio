#!/usr/bin/env bash
# url2vmov — DEV-ONLY helper: download a video and build a Vectrex .vmov from it.
#
# ⚠️  This is a personal development/testing utility. It is NOT part of the
#     distributed Vectrex Studio IDE (downloading from YouTube violates its ToS
#     and carries legal/app-store risk — the shipped IDE only imports LOCAL
#     files). YOU are responsible for the content's copyright and each site's
#     terms of service. Use only with material you have the right to use.
#
# Usage:
#   tools/fetch/url2vmov.sh <URL> <out_dir> <name> [mode] [fps] [epsilon] [budget]
#     mode: silhouette (Bad Apple / shadow art) | edges (Flash line-art)  [edges]
#
# Produces <out_dir>/<name>.mp4, <name>.vrec, <name>.vsmp, <name>.vmov.
# Requires: the tools/video2vrec/.venv (opencv + yt-dlp) and ffmpeg on PATH.
set -euo pipefail

URL="${1:?usage: url2vmov.sh <URL> <out_dir> <name> [mode] [fps] [epsilon] [budget]}"
OUT="${2:?missing out_dir}"
NAME="${3:?missing name}"
MODE="${4:-edges}"
FPS="${5:-12}"
EPS="${6:-2.5}"
BUDGET="${7:-250}"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VENV="$ROOT/tools/video2vrec/.venv/bin"
mkdir -p "$OUT"

echo "[1/4] downloading $URL"
"$VENV/yt-dlp" -f "bestvideo[ext=mp4][height<=480]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
  --merge-output-format mp4 -o "$OUT/$NAME.%(ext)s" "$URL"

echo "[2/4] video → vectors ($MODE)"
"$VENV/python" "$ROOT/tools/video2vrec/video2vrec.py" \
  "$OUT/$NAME.mp4" "$OUT/$NAME.vrec" \
  --mode "$MODE" --fps "$FPS" --epsilon "$EPS" --budget "$BUDGET" --border-margin 2

echo "[3/4] audio → 4-bit voice"
python3 "$ROOT/tools/audio2vsmp/audio2vsmp.py" \
  "$OUT/$NAME.mp4" "$OUT/$NAME.vsmp" --rate 8000 --normalize

echo "[4/4] writing $NAME.vmov"
cat > "$OUT/$NAME.vmov" <<EOF
{ "version": "1.0", "name": "$NAME", "fps": $FPS, "vrec": "$NAME.vrec", "vsmp": "$NAME.vsmp", "source": "$OUT/$NAME.mp4" }
EOF

echo "done → $OUT/$NAME.vmov  (open it in the IDE's Vector Movie editor)"
