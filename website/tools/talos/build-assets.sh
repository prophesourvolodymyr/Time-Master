#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
source_dir="$root/genesis/REFERENCE/website/talos"
public_dir="$root/website/public"

npx -y @gltf-transform/cli@4 optimize \
  "$source_dir/talos-raw.glb" "$public_dir/models/talos.glb" \
  --compress meshopt --texture-compress webp --texture-size 2048 --simplify false

cwebp -quiet -q 84 -alpha_q 90 -m 6 -sharp_yuv -resize 1000 1600 \
  "$source_dir/talos-poster-render.png" -o "$public_dir/media/chapters/ai/talos-poster.webp"
