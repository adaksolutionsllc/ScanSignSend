#!/usr/bin/env python3
"""Cut the App Store preview from a `capture.sh --video` recording.

    python3 tool/store_capture/make_preview.py [lang]

Input:  build/store_capture/raw/iPhone_17_Pro_Max/<lang>/preview_raw.mov + beats.txt
Output: build/store_capture/preview/<lang>/preview_886x1920.mp4

Apple's 6.9" preview spec: 886x1920, ≤30 fps, 15–30 s, H.264, and an audio
track (a silent one is fine). Captions are rendered by Chrome (proper shaping
for every script) as transparent PNGs and overlaid at each beat.
"""
from __future__ import annotations

import html
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H, FPS, MAX_S = 886, 1920, 30, 29.5

CAPTIONS = {
    "en": {
        "import": "Scan or import any form",
        "detect": "Finds the blanks for you",
        "fill": "Tap a field. Fill it in.",
        "sign": "Sign with your finger",
        "finish": "One tap to a final PDF",
        "pdf": "Signed. Dated. Offline.",
    },
}

CAP_H = 300  # caption band height at output size


def caption_png(text: str, out: str) -> None:
    page = f"""<!doctype html><html><head><meta charset="utf-8"></head>
<body style="margin:0;width:{W}px;height:{CAP_H}px;background:transparent;
  display:flex;align-items:center;justify-content:center;
  font-family:-apple-system,'SF Pro Display','Kohinoor Devanagari','Tamil Sangam MN','Kohinoor Telugu',sans-serif">
<div style="position:absolute;inset:0;background:linear-gradient(180deg,
  rgba(22,25,32,.96) 0%,rgba(22,25,32,.90) 70%,rgba(22,25,32,0) 100%)"></div>
<div style="position:relative;color:#fff;font-weight:800;font-size:62px;
  text-align:center;padding:40px 48px 70px;line-height:1.1">{html.escape(text)}</div>
</body></html>"""
    with tempfile.TemporaryDirectory() as tmp:
        p = os.path.join(tmp, "c.html")
        open(p, "w", encoding="utf-8").write(page)
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--default-background-color=00000000", "--force-device-scale-factor=1",
             f"--window-size={W},{CAP_H}", f"--screenshot={out}", f"file://{p}"],
            check=True, capture_output=True)


def duration(path: str) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "json", path], capture_output=True, text=True, check=True)
    return float(json.loads(r.stdout)["format"]["duration"])


def main() -> int:
    lang = sys.argv[1] if len(sys.argv) > 1 else "en"
    src_dir = os.path.join(ROOT, "build", "store_capture", "raw", "iPhone_17_Pro_Max", lang, "video")
    raw = os.path.join(src_dir, "preview_raw.mov")
    beats = [
        (float(t), name)
        for t, name in (l.split() for l in open(os.path.join(src_dir, "beats.txt")) if l.strip())
    ]
    out_dir = os.path.join(ROOT, "build", "store_capture", "preview", lang)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "preview_886x1920.mp4")

    total = duration(raw)
    speed = max(1.0, total / MAX_S)  # only ever speed up, never slow down
    print(f"raw {total:.1f}s → speed ×{speed:.2f} → {total / speed:.1f}s")

    caps = CAPTIONS.get(lang, CAPTIONS["en"])
    with tempfile.TemporaryDirectory() as tmp:
        inputs, chain = [], []
        # Constant frame rate and output size first; the simulator records
        # variable-rate frames at device resolution.
        chain.append(
            f"[0:v]setpts=PTS/{speed:.4f},fps={FPS},"
            f"scale={W}:-2:flags=lanczos,crop={W}:{H}:0:0,setsar=1[v0]")
        last = "v0"
        windows = [(t / speed, name) for t, name in beats if name in caps]
        for i, (start, name) in enumerate(windows):
            end = windows[i + 1][0] if i + 1 < len(windows) else total / speed
            png = os.path.join(tmp, f"{i}.png")
            caption_png(caps[name], png)
            inputs += ["-loop", "1", "-i", png]
            nxt = f"v{i + 1}"
            chain.append(
                f"[{last}][{i + 2}:v]overlay=0:0:shortest=1:"
                f"enable='between(t,{start:.2f},{end:.2f})'[{nxt}]")
            last = nxt
        cmd = [
            "ffmpeg", "-y", "-loglevel", "error", "-i", raw,
            "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
            *inputs,
            "-filter_complex", ";".join(chain),
            "-map", f"[{last}]", "-map", "1:a",
            "-t", f"{min(total / speed, 30):.2f}",
            "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p",
            "-r", str(FPS), "-b:v", "10M", "-maxrate", "12M", "-bufsize", "20M",
            "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2",
            "-movflags", "+faststart", out,
        ]
        subprocess.run(cmd, check=True)
    print(f"{os.path.relpath(out, ROOT)}  {duration(out):.1f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
