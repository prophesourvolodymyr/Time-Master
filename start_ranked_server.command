#!/bin/zsh
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="${0:A:h}"
STATE="$HOME/Library/Application Support/TimeMaster/Ranked Service"
mkdir -p "$STATE"
if [[ ! -x "$STATE/venv/bin/python3" ]]; then
    PYTHON=""
    for candidate in python3 python3.14 python3.13 python3.12 python3.11 python3.10; do
        if command -v "$candidate" >/dev/null && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
            PYTHON="$candidate"
            break
        fi
    done
    if [[ -z "$PYTHON" ]]; then
        print -u2 'TimeMaster Ranked requires Python 3.10 or newer.'
        exit 1
    fi
    "$PYTHON" -m venv "$STATE/venv"
fi
"$STATE/venv/bin/python3" -m pip install --disable-pip-version-check -r "$ROOT/ranked_server/requirements.txt"
export RANKED_DATABASE="$STATE/ranked.sqlite3"
export RANKED_REQUIRE_TLS=false
exec "$STATE/venv/bin/python3" -m uvicorn ranked_server.app:app --app-dir "$ROOT" --host 127.0.0.1 --port 8765 --no-access-log
