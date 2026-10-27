#!/usr/bin/env bash
# Generates the Social chapter stills with fgen (ChatGPT subscription, zero Higgsfield credits).
# Usage: tools/social/generate.sh [name ...]   (names match genesis/REFERENCE/website/social/prompts/<name>.txt)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
source_dir="$root/genesis/REFERENCE/website/social"
style_reference="$root/genesis/REFERENCE/website/hero-film/start-frame.png"

size_for() {
  case "$1" in
    arena | dust) echo "1680x944" ;;
    tablet-*) echo "1024x1024" ;;
    *) echo "1024x1536" ;;
  esac
}

references_for() {
  case "$1" in
    dust) ;;
    tablet-*) echo "$source_dir/candidates/${TABLET_REFERENCE:-spectator-left-a}.png" ;;
    *) echo "$style_reference" ;;
  esac
}

generate() {
  local name="$1"
  local args=(gen -q high -s "$(size_for "$name")" --timeout 900 --quiet -o "$source_dir/candidates/$name.png" -p "$(cat "$source_dir/prompts/$name.txt")")
  local reference
  reference="$(references_for "$name")"
  if [[ -n "$reference" ]]; then args+=(-i "$reference"); fi
  fgen "${args[@]}"
}

names=("$@")
if [[ ${#names[@]} -eq 0 ]]; then
  for prompt in "$source_dir"/prompts/*.txt; do names+=("$(basename "$prompt" .txt)"); done
fi

mkdir -p "$source_dir/candidates"
for name in "${names[@]}"; do generate "$name" & done
wait
