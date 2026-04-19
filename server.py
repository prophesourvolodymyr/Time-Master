#!/usr/bin/env python3
"""
Time-Master Companion Server
Downloads videos using yt-dlp and streams them to the iOS app.

Requirements:
    pip3 install yt-dlp

Usage:
    python3 server.py
"""

import http.server
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

HOST = "0.0.0.0"
PORT = 8888
DISCOVERY_PORT = 8889  # UDP broadcast port for auto-discovery
CHUNK_SIZE = 65536  # 64 KB

# Homebrew paths for yt-dlp and ffmpeg (used on macOS with Apple Silicon / Intel)
YTDLP_PATH = "/opt/homebrew/bin/yt-dlp"
if not os.path.exists(YTDLP_PATH):
    YTDLP_PATH = "/usr/local/bin/yt-dlp"   # Intel Homebrew fallback
if not os.path.exists(YTDLP_PATH):
    YTDLP_PATH = "yt-dlp"                   # last resort: rely on PATH

# Ensure ffmpeg is visible to yt-dlp even when PATH is restricted in subprocess
_env = os.environ.copy()
for extra in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]:
    if extra not in _env.get("PATH", ""):
        _env["PATH"] = extra + os.pathsep + _env.get("PATH", "")
SUBPROCESS_ENV = _env


class Handler(http.server.BaseHTTPRequestHandler):

    # ------------------------------------------------------------------ GET --

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/health":
            self._json(200, {"status": "ok"})
        else:
            self._json(404, {"error": "not found"})

    # ----------------------------------------------------------------- POST --

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/download":
            self._handle_download()
        else:
            self._json(404, {"error": "not found"})

    # ------------------------------------------------------------ /download --

    def _handle_download(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            data = json.loads(body)
        except Exception:
            self._json(400, {"error": "invalid JSON body"})
            return

        url = data.get("url", "").strip()
        if not url:
            self._json(400, {"error": "missing 'url' field"})
            return

        print(f"  → downloading: {url}")

        with tempfile.TemporaryDirectory() as tmpdir:
            out_template = os.path.join(tmpdir, "video.%(ext)s")
            cmd = [
                YTDLP_PATH,
                # Format priority (ensures iOS-compatible H.264+AAC output):
                # 1. Facebook native pre-muxed hd (H.264+AAC, no ffmpeg needed)
                # 2. Facebook native pre-muxed sd (H.264+AAC, no ffmpeg needed)
                # 3. Best mp4 that already has audio (other platforms, pre-muxed)
                # 4. Best mp4 video + m4a audio merged by ffmpeg
                # 5. Absolute fallback
                "-f", "hd/sd/best[ext=mp4][acodec!=none]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best",
                "--merge-output-format", "mp4",
                "-o", out_template,
                "--no-playlist",
                "--quiet",
                "--user-agent",
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                url,
            ]
            result = subprocess.run(cmd, capture_output=True, text=True,
                                    env=SUBPROCESS_ENV)
            if result.returncode != 0:
                msg = result.stderr.strip() or "yt-dlp failed"
                print(f"  ✗ yt-dlp error: {msg}")
                self._json(500, {"error": msg})
                return

            # Locate the output file
            mp4_path = None
            for fname in os.listdir(tmpdir):
                if fname.endswith(".mp4"):
                    mp4_path = os.path.join(tmpdir, fname)
                    break

            if not mp4_path or not os.path.exists(mp4_path):
                self._json(500, {"error": "output file not found after yt-dlp"})
                return

            file_size = os.path.getsize(mp4_path)
            print(f"  ✓ {os.path.basename(mp4_path)}  ({file_size // 1024} KB)")

            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(file_size))
            self.end_headers()

            with open(mp4_path, "rb") as f:
                while True:
                    chunk = f.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        print("  ! client disconnected mid-stream")
                        break

    # ---------------------------------------------------------------- utils --

    def _json(self, status: int, payload: dict):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{self.client_address[0]}] {fmt % args}")


# ====================================================================== main --

def get_lan_ip() -> str:
    """Return the machine's LAN IP (best-effort via UDP trick)."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def broadcast_presence(lan_ip: str, stop_event: threading.Event):
    """Broadcast UDP beacon every 2 s so the iOS app can auto-detect this server."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(1)
    message = f"TIMEMASTER:{lan_ip}:{PORT}".encode()
    while not stop_event.is_set():
        try:
            sock.sendto(message, ("255.255.255.255", DISCOVERY_PORT))
        except Exception:
            pass
        time.sleep(2)
    sock.close()


def main():
    lan_ip = get_lan_ip()
    print("=" * 52)
    print("  Time-Master Companion Server")
    print("=" * 52)
    print()
    print("  Setup (one-time):")
    print("    pip3 install yt-dlp")
    print()
    print(f"  LAN IP:       {lan_ip}")
    print(f"  Listening on  http://{HOST}:{PORT}")
    print(f"  Broadcasting  UDP beacon on port {DISCOVERY_PORT} every 2 s")
    print("  (iOS app will auto-detect this server)")
    print()
    print("  Endpoints:")
    print("    GET  /health              → {\"status\": \"ok\"}")
    print("    POST /download            → streams .mp4")
    print("         body: {\"url\": \"<social-url>\"}")
    print()
    print("  Press Ctrl+C to stop.")
    print()

    stop_event = threading.Event()
    beacon = threading.Thread(target=broadcast_presence, args=(lan_ip, stop_event), daemon=True)
    beacon.start()

    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        stop_event.set()
        server.server_close()
        sys.exit(0)


if __name__ == "__main__":
    main()
