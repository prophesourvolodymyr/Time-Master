# Talos 3D sources

## Reference views (fgen, free)

Command: `fgen gen -q high -s 1024x1536 -i <refs> -o views/<view>.png --quiet -p "<prompt>"`

- `views/front.png`: refs `TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png`, `genesis/REFERENCE/tmax-branding/email-welcome-mascot.png`. Prompt: character turnaround reference sheet, front view, same character (ivory Carrara marble athlete, bald, fluted lower-face mask, charcoal scarf draped as a short cape, black slit shorts, orange knotted belt, orange wrist wraps, barefoot), neutral symmetrical A-pose, full body, long lens, soft even light, plain pure white background, no text.
- `views/three-quarter.png`, `views/side.png`, `views/back.png`: refs `views/front.png` + the Ranked hero art. Same character and pose, rotated 45 degrees (left side toward camera), 90 degree left profile, and 180 degree back view.

All four views were inspected side by side and approved as consistent before spending credits.

## Image to 3D (Higgsfield, one generation)

- Model: `tripo_h3_1_image_to_3d` (Tripo H3.1), input `views/front.png`.
- Params: `geometry_quality=detailed`, `texture_quality=detailed`, `face_limit=100000`, `orientation=align_image`, `pbr=true`.
- Cost check: `higgsfield generate cost` reported 18 credits. Charged: 18 credits (balance 260 to 242). Job record: `job.json`.
- Output: `talos-raw.glb` (97,760 triangles, 4K PBR textures, 9.9 MB).

## Web output

`website/tools/talos/build-assets.sh` writes `website/public/models/talos.glb` (meshopt + WebP 2048 textures, about 0.9 MB) and `website/public/media/chapters/ai/talos-poster.webp` from `talos-poster-render.png`, a transparent render of the optimized model in the site's light rig at the chapter's rest pose.
