#!/usr/bin/env python3
"""Local-only VideoPocket download helper. Requires Python 3.10+ and yt-dlp."""
from __future__ import annotations
import json, os, secrets, subprocess, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

SOURCE_ROOT = Path(__file__).resolve().parent
DATA_ROOT = Path.home() / "Library" / "Application Support" / "VideoPocket"
DATA_ROOT.mkdir(parents=True, exist_ok=True)
CONFIG_PATH = DATA_ROOT / "config.json"

def bundled_tool(name: str) -> Path | None:
    if getattr(sys, "frozen", False):
        candidate = Path(sys.executable).resolve().parent.parent / "Resources" / "bin" / name
        if candidate.exists(): return candidate
    return None
ALLOWED = ("x.com", "twitter.com", "facebook.com", "instagram.com", "linkedin.com", "youtube.com", "youtu.be")
VERSION = "0.4.1"

def config():
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps({"token": secrets.token_urlsafe(24), "download_dir": str(Path.home()/"Downloads"/"VideoPocket")}, indent=2)+"\n")
        os.chmod(CONFIG_PATH, 0o600)
    return json.loads(CONFIG_PATH.read_text())

def allowed_url(value: str) -> bool:
    try:
        parsed = urlparse(value)
        host = (parsed.hostname or "").lower()
        return parsed.scheme == "https" and any(host == d or host.endswith("."+d) for d in ALLOWED)
    except Exception:
        return False

def extension_origin(headers) -> bool:
    return headers.get("Origin", "").startswith("chrome-extension://")

def download_and_normalize(url: str, output_dir: Path) -> None:
    log_path = DATA_ROOT / "helper.log"
    template = output_dir / "%(uploader)s - %(title).150B [%(id)s].%(ext)s"
    yt_dlp_bin = bundled_tool("yt-dlp")
    download = ([str(yt_dlp_bin)] if yt_dlp_bin else [sys.executable, "-m", "yt_dlp"]) + ["--no-playlist", "--restrict-filenames", "--merge-output-format", "mp4", "--remux-video", "mp4", "--quiet", "--no-warnings", "--print", "after_move:filepath", "-o", str(template), url]
    with log_path.open("a") as log:
        log.write(f"\nDownloading: {url}\n")
        result = subprocess.run(download, text=True, stdout=subprocess.PIPE, stderr=log)
        if result.returncode != 0: log.write("Download failed.\n"); return
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if not lines: log.write("Download completed but yt-dlp returned no output path.\n"); return
        source = Path(lines[-1]).expanduser()
        if not source.exists(): log.write(f"Downloaded file was not found: {source}\n"); return
        temporary = source.with_name(f".{source.stem}.normalizing.mp4")
        ffmpeg_bin = bundled_tool("ffmpeg")
        normalize = [str(ffmpeg_bin or "ffmpeg"), "-y", "-i", str(source), "-map", "0:v:0", "-map", "0:a?", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", "-preset", "fast", "-crf", "20", "-pix_fmt", "yuv420p", "-metadata:s:v:0", "rotate=0", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(temporary)]
        converted = subprocess.run(normalize, stdout=log, stderr=subprocess.STDOUT)
        if converted.returncode == 0 and temporary.exists(): temporary.replace(source); log.write(f"Ready: {source}\n")
        else: temporary.unlink(missing_ok=True); log.write("Normalization failed; original download was preserved.\n")

class Handler(BaseHTTPRequestHandler):
    server_version = f"VideoPocket/{VERSION}"
    def log_message(self, fmt, *args): print(fmt % args)
    def cors(self):
        origin = self.headers.get("Origin", "")
        if origin.startswith("chrome-extension://"):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-VideoPocket-Token")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    def reply(self, code, payload):
        data=json.dumps(payload).encode(); self.send_response(code); self.cors(); self.send_header("Content-Type","application/json"); self.send_header("Content-Length",str(len(data))); self.end_headers(); self.wfile.write(data)
    def do_OPTIONS(self): self.send_response(204); self.cors(); self.end_headers()
    def do_GET(self):
        self.reply(200, {"ok": True, "version": VERSION}) if self.path == "/health" else self.reply(404, {"error":"Not found"})
    def do_POST(self):
        cfg=config()
        if self.path == "/pair":
            if not extension_origin(self.headers): return self.reply(403, {"error":"Pairing is available only to the VideoPocket extension"})
            return self.reply(200, {"token": cfg["token"]})
        if self.path != "/download": return self.reply(404, {"error":"Not found"})
        token_ok = secrets.compare_digest(self.headers.get("X-VideoPocket-Token", ""), cfg["token"])
        if not extension_origin(self.headers) and not token_ok: return self.reply(401, {"error":"Request did not come from VideoPocket"})
        try:
            length=int(self.headers.get("Content-Length","0")); body=json.loads(self.rfile.read(min(length, 65536)))
            url=body.get("url","")
            if not allowed_url(url): return self.reply(400, {"error":"Unsupported or unsafe URL"})
            out=Path(cfg["download_dir"]).expanduser(); out.mkdir(parents=True,exist_ok=True)
            threading.Thread(target=download_and_normalize, args=(url, out), daemon=True).start()
            self.reply(202, {"queued":True,"folder":str(out)})
        except Exception as exc: self.reply(500, {"error":str(exc)})

if __name__ == "__main__":
    cfg=config()
    if "--init" in sys.argv: print("VideoPocket is ready"); raise SystemExit(0)
    print(f"VideoPocket Helper {VERSION} on http://127.0.0.1:17839\nDownloads: {cfg['download_dir']}")
    ThreadingHTTPServer(("127.0.0.1",17839),Handler).serve_forever()
