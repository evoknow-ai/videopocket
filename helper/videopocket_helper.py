#!/usr/bin/env python3
"""Local-only VideoPocket download helper. Requires Python 3.10+ and yt-dlp."""
from __future__ import annotations
import json, os, re, secrets, subprocess, sys, threading, time, uuid
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

SOURCE_ROOT = Path(__file__).resolve().parent
DATA_ROOT = Path.home() / "Library" / "Application Support" / "VideoPocket"
CONFIG_PATH = DATA_ROOT / "config.json"
LOG_PATH = DATA_ROOT / "helper.log"

def bundled_tool(name: str) -> Path | None:
    if getattr(sys, "frozen", False):
        candidate = Path(sys.executable).resolve().parent.parent / "Resources" / "bin" / name
        if candidate.exists(): return candidate
    return None
ALLOWED = ("x.com", "twitter.com", "facebook.com", "instagram.com", "linkedin.com", "youtube.com", "youtu.be")
VERSION = "0.4.6"
JOBS: dict[str, dict] = {}
JOBS_LOCK = threading.Lock()

def set_job(job_id: str, **values) -> None:
    with JOBS_LOCK:
        JOBS.setdefault(job_id, {}).update(values, updated_at=time.time())

def job_snapshot(job_id: str | None = None) -> dict:
    with JOBS_LOCK:
        if job_id and job_id in JOBS: return dict(JOBS[job_id])
        if not JOBS: return {"state": "idle"}
        return dict(max(JOBS.values(), key=lambda item: item.get("updated_at", 0)))

def config():
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    if not CONFIG_PATH.exists():
        CONFIG_PATH.write_text(json.dumps({"token": secrets.token_urlsafe(24), "download_dir": str(Path.home()/"Downloads"/"VideoPocket"/"downloads")}, indent=2)+"\n")
        os.chmod(CONFIG_PATH, 0o600)
    cfg = json.loads(CONFIG_PATH.read_text())
    legacy = Path.home()/"Downloads"/"VideoPocket"
    if Path(cfg.get("download_dir", "")).expanduser() == legacy:
        cfg["download_dir"] = str(legacy/"downloads")
        CONFIG_PATH.write_text(json.dumps(cfg, indent=2)+"\n")
    return cfg

def recent_log(lines: int = 80) -> str:
    if not LOG_PATH.exists():
        return "No download activity has been logged yet."
    return "\n".join(LOG_PATH.read_text(errors="replace").splitlines()[-lines:])

def allowed_url(value: str) -> bool:
    try:
        parsed = urlparse(value)
        host = (parsed.hostname or "").lower()
        return parsed.scheme == "https" and any(host == d or host.endswith("."+d) for d in ALLOWED)
    except Exception:
        return False

def extension_origin(headers) -> bool:
    return headers.get("Origin", "").startswith("chrome-extension://")

def request_authorized(headers, cfg: dict) -> bool:
    """Accept Chrome's extension origin or the helper's private pairing token.

    Chrome can omit Origin on extension GET requests, so protected read-only
    endpoints must not rely on that header alone.
    """
    if extension_origin(headers):
        return True
    supplied = headers.get("X-VideoPocket-Token", "")
    expected = cfg.get("token", "")
    return bool(supplied and expected and secrets.compare_digest(supplied, expected))

def source_name(url: str) -> str:
    host = (urlparse(url).hostname or "").lower()
    if host in ("x.com", "twitter.com") or host.endswith((".x.com", ".twitter.com")): return "x"
    if "facebook.com" in host: return "fb"
    if "instagram.com" in host: return "ig"
    if "linkedin.com" in host: return "linkedin"
    return "youtube"

def already_quicktime_compatible(source: Path, ffmpeg: Path | None, log) -> bool:
    """Use FFmpeg's stream report when a normalization attempt cannot finish."""
    try:
        probe = subprocess.run(
            [str(ffmpeg or "ffmpeg"), "-hide_banner", "-i", str(source)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            errors="replace",
        )
    except Exception as exc:
        log.write(f"Could not inspect the original video: {exc}\n")
        return False
    report = probe.stderr.lower()
    video_ok = re.search(r"video:\s*(h264|avc)", report) is not None
    audio_streams = re.findall(r"audio:\s*([a-z0-9_]+)", report)
    audio_ok = not audio_streams or all(codec == "aac" for codec in audio_streams)
    rotated = re.search(r"rotation of\s+(?!-?0(?:\.0+)?\s+degrees)", report) is not None
    return video_ok and audio_ok and not rotated

def download_and_normalize(job_id: str, url: str, output_root: Path) -> None:
    import yt_dlp
    output_dir = output_root / source_name(url)
    output_dir.mkdir(parents=True, exist_ok=True)
    template = output_dir / f"{date.today().isoformat()}-%(uploader).60B-%(id)s.%(ext)s"
    ffmpeg_bin = bundled_tool("ffmpeg")
    def progress_hook(event):
        state = event.get("status")
        if state == "downloading":
            total = event.get("total_bytes") or event.get("total_bytes_estimate") or 0
            done = event.get("downloaded_bytes") or 0
            percent = round(done * 100 / total, 1) if total else None
            set_job(job_id, state="downloading", stage="Downloading", percent=percent,
                    filename=Path(event.get("filename", "video")).name)
        elif state == "finished":
            set_job(job_id, state="processing", stage="Merging and preparing", percent=100,
                    filename=Path(event.get("filename", "video")).name)

    options = {
        "noplaylist": True, "restrictfilenames": True, "quiet": True,
        "no_warnings": True, "outtmpl": str(template), "merge_output_format": "mp4",
        "format": "bestvideo[vcodec^=avc1]+bestaudio/best[vcodec^=h264]+bestaudio/best[vcodec^=avc1]/best[vcodec^=h264]/bestvideo+bestaudio/best",
        "postprocessors": [{"key": "FFmpegVideoRemuxer", "preferedformat": "mp4"}],
        "progress_hooks": [progress_hook],
    }
    if ffmpeg_bin: options["ffmpeg_location"] = str(ffmpeg_bin.parent)
    with LOG_PATH.open("a") as log:
        log.write(f"\nDownloading: {url}\n")
        try:
            with yt_dlp.YoutubeDL(options) as downloader:
                info = downloader.extract_info(url, download=True)
                source = Path(downloader.prepare_filename(info)).with_suffix(".mp4")
        except Exception as exc:
            log.write(f"Download failed: {exc}\n")
            set_job(job_id, state="error", stage="Failed", error=str(exc))
            return
        if not source.exists():
            message = f"Downloaded file was not found: {source}"
            log.write(message+"\n"); set_job(job_id, state="error", stage="Failed", error=message); return
        set_job(job_id, state="processing", stage="Converting for QuickTime", percent=100, filename=source.name)
        temporary = source.with_name(f".{source.stem}.normalizing.mp4")
        ffmpeg_bin = bundled_tool("ffmpeg")
        common = [str(ffmpeg_bin or "ffmpeg"), "-y", "-i", str(source), "-map", "0:v:0", "-map", "0:a?", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-pix_fmt", "yuv420p", "-tag:v", "avc1", "-metadata:s:v:0", "rotate=0", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart"]
        encoders = [
            ["-c:v", "h264_videotoolbox", "-b:v", "6M"],
            ["-c:v", "libx264", "-preset", "fast", "-crf", "20"],
        ]
        converted = False
        conversion_error = ""
        for encoder in encoders:
            temporary.unlink(missing_ok=True)
            try:
                result = subprocess.run(
                    common + encoder + [str(temporary)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    errors="replace",
                )
                output = result.stdout or ""
                if output:
                    log.write(output)
                if result.returncode == 0 and temporary.exists() and temporary.stat().st_size > 0:
                    converted = True
                    break
                tail = "\n".join(output.strip().splitlines()[-12:])
                conversion_error = tail or f"FFmpeg exited with status {result.returncode}."
            except Exception as exc:
                conversion_error = str(exc)
            log.write(f"Compatibility conversion with {encoder[1]} failed; trying fallback.\n")
            log.flush()
        if converted:
            temporary.replace(source)
            log.write(f"Ready (H.264/AAC): {source}\n")
            set_job(job_id, state="ready", stage="Ready", percent=100, filename=source.name, path=str(source))
        elif already_quicktime_compatible(source, ffmpeg_bin, log):
            temporary.unlink(missing_ok=True)
            log.write(f"Ready: the original is already H.264/AAC compatible: {source}\n")
            set_job(job_id, state="ready", stage="Ready", percent=100, filename=source.name, path=str(source))
        else:
            temporary.unlink(missing_ok=True)
            source.rename(source.with_suffix(".incompatible.mp4"))
            message = "Could not create a QuickTime-compatible video"
            if conversion_error:
                message += f": {conversion_error}"
            log.write(f"{message}\nThe original was marked incompatible.\n")
            set_job(job_id, state="error", stage="Conversion failed", error=message)

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
        if self.path == "/health":
            return self.reply(200, {"ok": True, "version": VERSION})
        if self.path == "/errors":
            if not request_authorized(self.headers, config()): return self.reply(403, {"error":"VideoPocket could not authenticate with the Mac Helper"})
            return self.reply(200, {"ok": True, "log": recent_log()})
        if self.path.startswith("/download-status"):
            if not request_authorized(self.headers, config()): return self.reply(403, {"error":"VideoPocket could not authenticate with the Mac Helper"})
            job_id = self.path.partition("?")[2].removeprefix("id=") or None
            return self.reply(200, {"ok": True, "job": job_snapshot(job_id)})
        self.reply(404, {"error":"Not found"})
    def do_POST(self):
        cfg=config()
        if self.path == "/pair":
            if not extension_origin(self.headers): return self.reply(403, {"error":"Pairing is available only to the VideoPocket extension"})
            return self.reply(200, {"token": cfg["token"]})
        if not request_authorized(self.headers, cfg): return self.reply(401, {"error":"Request did not come from VideoPocket"})
        if self.path == "/open-downloads":
            try:
                folder=Path(cfg["download_dir"]).expanduser(); folder.mkdir(parents=True,exist_ok=True)
                subprocess.Popen(["open", str(folder)])
                return self.reply(200, {"ok":True,"folder":str(folder)})
            except Exception as exc: return self.reply(500, {"error":str(exc)})
        if self.path != "/download": return self.reply(404, {"error":"Not found"})
        try:
            length=int(self.headers.get("Content-Length","0")); body=json.loads(self.rfile.read(min(length, 65536)))
            url=body.get("url","")
            if not allowed_url(url): return self.reply(400, {"error":"Unsupported or unsafe URL"})
            out=Path(cfg["download_dir"]).expanduser(); out.mkdir(parents=True,exist_ok=True)
            job_id = uuid.uuid4().hex
            set_job(job_id, id=job_id, state="queued", stage="Waiting to start", percent=0, filename=body.get("title") or "video")
            threading.Thread(target=download_and_normalize, args=(job_id, url, out), daemon=True).start()
            self.reply(202, {"queued":True,"jobId":job_id,"folder":str(out)})
        except Exception as exc: self.reply(500, {"error":str(exc)})

if __name__ == "__main__":
    cfg=config()
    if "--init" in sys.argv: print("VideoPocket is ready"); raise SystemExit(0)
    print(f"VideoPocket Helper {VERSION} on http://127.0.0.1:17839\nDownloads: {cfg['download_dir']}")
    ThreadingHTTPServer(("127.0.0.1",17839),Handler).serve_forever()
