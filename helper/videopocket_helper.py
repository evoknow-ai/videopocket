#!/usr/bin/env python3
"""Local-only VideoPocket download helper. Requires Python 3.10+ and yt-dlp."""
from __future__ import annotations
import json, os, re, secrets, subprocess, sys, threading
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.json"
ALLOWED = ("x.com", "twitter.com", "facebook.com", "instagram.com", "linkedin.com", "youtube.com", "youtu.be")

def config():
    default_download_dir = Path.home()/"Downloads"/"VideoPocket"/"downloads"
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps({"token": secrets.token_urlsafe(24), "download_dir": str(default_download_dir)}, indent=2)+"\n")
        os.chmod(CONFIG_PATH, 0o600)
    cfg = json.loads(CONFIG_PATH.read_text())
    legacy_download_dir = Path.home()/"Downloads"/"VideoPocket"
    configured_dir = Path(cfg.get("download_dir", default_download_dir)).expanduser()
    if configured_dir == legacy_download_dir:
        cfg["download_dir"] = str(default_download_dir)
        CONFIG_PATH.write_text(json.dumps(cfg, indent=2)+"\n")
        os.chmod(CONFIG_PATH, 0o600)
    return cfg

def allowed_url(value: str) -> bool:
    try:
        host = (urlparse(value).hostname or "").lower()
        return urlparse(value).scheme == "https" and any(host == d or host.endswith("."+d) for d in ALLOWED)
    except Exception:
        return False

def source_key(value: str) -> str:
    host = (urlparse(value).hostname or "").lower()
    if host == "x.com" or host.endswith(".x.com") or "twitter.com" in host: return "x"
    if "facebook.com" in host: return "fb"
    if "instagram.com" in host: return "ig"
    if "linkedin.com" in host: return "linkedin"
    if "youtube.com" in host or host == "youtu.be": return "youtube"
    return "other"

def download_and_normalize(url: str, output_root: Path) -> None:
    """Download, then create a universally playable MP4 with rotation applied."""
    log_path = ROOT / "helper.log"
    output_dir = output_root / source_key(url)
    output_dir.mkdir(parents=True, exist_ok=True)
    downloaded_on = datetime.now().strftime("%Y-%m-%d")
    template = output_dir / f"{downloaded_on}-%(uploader).50B-%(id)s.%(ext)s"
    download = [
        sys.executable, "-m", "yt_dlp", "--no-playlist", "--restrict-filenames",
        "--merge-output-format", "mp4", "--remux-video", "mp4",
        "--quiet", "--no-warnings", "--print", "after_move:filepath",
        "-o", str(template), url,
    ]
    with log_path.open("a") as log:
        log.write(f"\nDownloading: {url}\n")
        result = subprocess.run(download, text=True, stdout=subprocess.PIPE, stderr=log)
        if result.returncode != 0:
            log.write("Download failed.\n")
            return
        lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        if not lines:
            log.write("Download completed but yt-dlp returned no output path.\n")
            return
        source = Path(lines[-1]).expanduser()
        if not source.exists():
            log.write(f"Downloaded file was not found: {source}\n")
            return
        temporary = source.with_name(f".{source.stem}.normalizing.mp4")
        normalize = [
            "ffmpeg", "-y", "-i", str(source),
            "-map", "0:v:0", "-map", "0:a?",
            "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:v", "libx264", "-preset", "fast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-metadata:s:v:0", "rotate=0",
            "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart",
            str(temporary),
        ]
        log.write(f"Normalizing for QuickTime: {source.name}\n")
        converted = subprocess.run(normalize, stdout=log, stderr=subprocess.STDOUT)
        if converted.returncode == 0 and temporary.exists():
            temporary.replace(source)
            log.write(f"Ready: {source}\n")
        else:
            temporary.unlink(missing_ok=True)
            log.write("Normalization failed; original download was preserved.\n")

class Handler(BaseHTTPRequestHandler):
    server_version = "VideoPocket/0.1"
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
        self.reply(200, {"ok": True}) if self.path == "/health" else self.reply(404, {"error":"Not found"})
    def do_POST(self):
        cfg=config()
        if self.path == "/pair":
            origin = self.headers.get("Origin", "")
            if not origin.startswith("chrome-extension://"):
                return self.reply(403, {"error":"Pairing is available only to a Chrome extension"})
            return self.reply(200, {"token": cfg["token"]})
        if self.path != "/download": return self.reply(404, {"error":"Not found"})
        if not secrets.compare_digest(self.headers.get("X-VideoPocket-Token", ""), cfg["token"]): return self.reply(401, {"error":"Incorrect helper token"})
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
    if "--init" in sys.argv:
        print(cfg["token"])
        raise SystemExit(0)
    print(f"VideoPocket helper on http://127.0.0.1:17839\nDownloads: {cfg['download_dir']}\nToken: {cfg['token']}")
    ThreadingHTTPServer(("127.0.0.1",17839),Handler).serve_forever()
