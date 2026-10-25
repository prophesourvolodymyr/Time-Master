#!/usr/bin/env python3
"""
Time-Master Companion Server
Validates video links with yt-dlp and streams downloads to the iOS app.

Requirements on macOS:
    brew install yt-dlp ffmpeg

Usage:
    python3 server.py
"""

import http.server
import json
import os
import select
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

HOST = "0.0.0.0"
PORT = 8888
DISCOVERY_PORT = 8889
CHUNK_SIZE = 65536

SUBPROCESS_ENV = os.environ.copy()
_tool_directories = ["/opt/homebrew/bin", "/usr/local/bin",
                     os.path.expanduser("~/.local/bin"), os.path.expanduser("~/.deno/bin")]
_tool_directories += SUBPROCESS_ENV.get("PATH", "").split(os.pathsep)
_tool_directories += ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
SUBPROCESS_ENV["PATH"] = os.pathsep.join(dict.fromkeys(path for path in _tool_directories if path))
SUBPROCESS_ENV["PYTHONUNBUFFERED"] = "1"
YTDLP_PATH = shutil.which("yt-dlp", path=SUBPROCESS_ENV["PATH"])
FFMPEG_PATH = shutil.which("ffmpeg", path=SUBPROCESS_ENV["PATH"])
DENO_PATH = shutil.which("deno", path=SUBPROCESS_ENV["PATH"])
NODE_PATH = shutil.which("node", path=SUBPROCESS_ENV["PATH"])


def extractor_arguments():
    arguments = ["--no-playlist", "--no-progress", "--socket-timeout", "30"]
    if FFMPEG_PATH:
        arguments += ["--ffmpeg-location", os.path.dirname(FFMPEG_PATH)]
    if DENO_PATH:
        arguments += ["--js-runtimes", f"deno:{DENO_PATH}"]
    elif NODE_PATH:
        arguments += ["--js-runtimes", f"node:{NODE_PATH}"]
    return arguments


class DownloadCancelled(Exception):
    pass


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if urllib.parse.urlparse(self.path).path == "/health":
            self._json(200, {"status": "ok" if YTDLP_PATH else "unavailable",
                             "downloader": YTDLP_PATH is not None,
                             "ffmpeg": FFMPEG_PATH is not None})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path not in ("/validate", "/download"):
            self._json(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 1048576:
                raise ValueError("invalid request size")
            data = json.loads(self.rfile.read(length))
            url = data.get("url", "") if isinstance(data, dict) else ""
            if not isinstance(url, str):
                raise ValueError("missing 'url' field")
            url = url.strip()
            parsed = urllib.parse.urlsplit(url)
            if parsed.scheme.lower() not in ("http", "https") or not parsed.hostname:
                raise ValueError("Enter a valid http or https video link.")
        except (ValueError, TypeError) as error:
            self._json(400, {"error": str(error)})
            return
        if not YTDLP_PATH:
            self._json(503, {"error": "yt-dlp was not found. Run brew install yt-dlp ffmpeg on the companion Mac, then restart the server."})
            return
        try:
            if path == "/validate":
                self._handle_validate(url)
            else:
                self._handle_download(url)
        except DownloadCancelled:
            print("  ! client cancelled import")
        except (BrokenPipeError, ConnectionResetError):
            print("  ! client disconnected")
        except subprocess.TimeoutExpired:
            self._json(504, {"error": "yt-dlp timed out. Retry or open the original link."})
        except OSError as error:
            self._json(503, {"error": str(error)})

    def _handle_validate(self, url):
        with tempfile.TemporaryDirectory() as directory:
            result, output, errors = self._run(
                extractor_arguments() + ["--skip-download", "--dump-single-json", "--", url], directory)
            if result != 0:
                self._json(422, {"error": self._failure(output, errors)})
                return
            try:
                info = json.loads(output)
                if not isinstance(info, dict):
                    raise ValueError()
            except ValueError:
                self._json(502, {"error": "yt-dlp returned unreadable video information."})
                return
            if info.get("is_live"):
                self._json(422, {"error": "This video is live. Import it after the broadcast ends."})
                return
            self._json(200, {"title": info.get("title"), "duration": info.get("duration"),
                             "extractor": info.get("extractor")})

    def _handle_download(self, url):
        print(f"  → downloading: {url}")
        with tempfile.TemporaryDirectory() as directory:
            arguments = extractor_arguments() + [
                "--format", "bv*[vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b",
                "--merge-output-format", "mp4", "--recode-video", "mp4",
                "--paths", directory, "--output", "video.%(ext)s",
                "--print", "after_move:filepath", "--", url,
            ]
            result, output, errors = self._run(arguments, directory)
            if result != 0:
                self._json(422, {"error": self._failure(output, errors)})
                return
            root = os.path.realpath(directory) + os.sep
            video_path = next((os.path.realpath(line.strip()) for line in reversed(output.splitlines())
                               if os.path.realpath(line.strip()).startswith(root)
                               and line.strip().lower().endswith(".mp4")
                               and os.path.isfile(line.strip())), None)
            if not video_path or os.path.getsize(video_path) == 0:
                self._json(502, {"error": "yt-dlp finished without a video file. Open the original link to check availability."})
                return
            self.send_response(200)
            self.send_header("Content-Type", "video/mp4")
            self.send_header("Content-Length", str(os.path.getsize(video_path)))
            self.end_headers()
            with open(video_path, "rb") as video:
                while chunk := video.read(CHUNK_SIZE):
                    self.wfile.write(chunk)

    def _run(self, arguments, directory):
        with tempfile.TemporaryFile(mode="w+b") as output, tempfile.TemporaryFile(mode="w+b") as errors:
            process = subprocess.Popen([YTDLP_PATH] + arguments, stdout=output, stderr=errors,
                                       cwd=directory, env=SUBPROCESS_ENV, start_new_session=True)
            deadline = time.monotonic() + 1800
            try:
                while process.poll() is None:
                    if time.monotonic() >= deadline:
                        raise subprocess.TimeoutExpired(process.args, 1800)
                    readable, _, _ = select.select([self.connection], [], [], 0.2)
                    if readable and not self.connection.recv(1, socket.MSG_PEEK):
                        raise DownloadCancelled()
                output.seek(0)
                errors.seek(0)
                return process.returncode, output.read().decode("utf-8", errors="replace"), errors.read().decode("utf-8", errors="replace")
            finally:
                if process.poll() is None:
                    try:
                        os.killpg(process.pid, signal.SIGINT)
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                    except ProcessLookupError:
                        process.wait()

    @staticmethod
    def _failure(output, errors):
        lines = [line.strip() for line in (errors or output).splitlines() if line.strip()]
        return "\n".join(lines[-12:]) or "yt-dlp could not download this video. Open the original link or retry."

    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{self.client_address[0]}] {fmt % args}")


def get_lan_ip():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as connection:
            connection.connect(("8.8.8.8", 80))
            return connection.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def broadcast_presence(lan_ip, stop_event):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as connection:
        connection.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        connection.settimeout(1)
        message = f"TIMEMASTER:{lan_ip}:{PORT}".encode()
        while not stop_event.is_set():
            try:
                connection.sendto(message, ("255.255.255.255", DISCOVERY_PORT))
            except OSError:
                pass
            stop_event.wait(2)


def main():
    lan_ip = get_lan_ip()
    print("Time-Master Companion Server")
    print(f"yt-dlp: {YTDLP_PATH or 'not installed — brew install yt-dlp ffmpeg'}")
    print(f"Listening on http://{HOST}:{PORT}; LAN http://{lan_ip}:{PORT}")
    print("GET /health · POST /validate · POST /download  —  body: {\"url\": \"https://…\"}")
    stop_event = threading.Event()
    beacon = threading.Thread(target=broadcast_presence, args=(lan_ip, stop_event), daemon=True)
    beacon.start()
    server = http.server.ThreadingHTTPServer((HOST, PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        stop_event.set()
        server.server_close()


if __name__ == "__main__":
    main()
