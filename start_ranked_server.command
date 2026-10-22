#!/bin/zsh
set -euo pipefail
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="${0:A:h}"
STATE="$HOME/Library/Application Support/TimeMaster/Ranked Service"
mkdir -p "$STATE"
if [[ -f "$STATE/cloud.env" ]]; then
    source "$STATE/cloud.env"
fi
if ! command -v cargo >/dev/null; then
    print -u2 'TimeMaster Ranked requires Rust to build the server. Install the stable toolchain from https://rustup.rs.'
    exit 1
fi
cargo build --release --locked --manifest-path "$ROOT/ranked_server/Cargo.toml" --target-dir "$STATE/build"
export RANKED_DATABASE="$STATE/ranked.sqlite3"
export RANKED_REQUIRE_TLS=false
export RANKED_TRUST_PROXY=false
export RANKED_BIND=127.0.0.1:8765
exec "$STATE/build/release/timemaster-ranked"
