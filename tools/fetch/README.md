# fetch — DEV-ONLY video download helper

⚠️ **Not part of the distributed Vectrex Studio IDE.** The shipped IDE only
imports LOCAL files. Downloading from YouTube violates its ToS and carries
legal / app-store risk, so a downloader must never be bundled in the product.
This script is a personal development/testing convenience only — **you are
responsible** for each video's copyright and each site's terms of service. Use
only with material you have the right to use.

## `url2vmov.sh`

One command: URL → a Vectrex `.vmov` (video vectors + 4-bit voice), ready to open
in the IDE's Vector Movie editor.

```bash
tools/fetch/url2vmov.sh <URL> <out_dir> <name> [mode] [fps] [epsilon] [budget]
#   mode: silhouette (Bad Apple / shadow art) | edges (Flash line-art)  [default edges]
```

Produces `<out_dir>/<name>.{mp4,vrec,vsmp,vmov}`. Then open the `.vmov` in the IDE.

Requires the `tools/video2vrec/.venv` (opencv + yt-dlp) and ffmpeg on PATH:
```bash
tools/video2vrec/.venv/bin/pip install yt-dlp
```
