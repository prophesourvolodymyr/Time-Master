# F30-E — Media Production

Every image, film, recording, and 3D model on the website, where it comes from, and the rules that keep it real, consistent, and affordable.

## What We Build

- Real screen recordings of the Tmax iPhone app, made by us, for the hero phone, the feature film, and every chapter.
- The hero film: one Kling 4.0 generation on Higgsfield, made from two approved stills and post-processed so the green phone screen can show our recordings.
- Talos, the AI mascot, as a real 3D model.
- Cinematic stills generated with `fgen` for the Social chapter parallax scene, the download call to action background, and chapter atmosphere, composited with real brand marks by us.

## App Recordings

- **Source:** the real Tmax iPhone app running in the iOS Simulator, on the newest available iPhone Pro simulator with the newest iOS runtime unless it misbehaves. Each recording is captured from the device screen.
- **Isolation:** recordings never use or modify the user's personal app data, accounts, or keys. A separate simulator data set is prepared with believable demo content: well-named workouts, an exercise library with real cover art from the app's own illustration assets, a recorded outdoor route, analytics history, a weekly schedule, music destinations, Ranked levels, and a styled profile with collectibles.
- **Clean presentation:** the status bar is cleaned to a classic showcase state (9:41, full battery, full signal, no carrier clutter). The app runs in its normal dark appearance with no debug overlays. Motions are deliberate and human-paced: real taps, real scrolling, and real transitions.
- **Coverage:** one short clip per feature, each about six to twelve seconds long and starting on a strong first frame. The feature film needs Home, Workout player, Timer, Builder, Database, Map recording, Routes, AI Coach chat, Agent settings, Analytics, Streaks, Schedule, Music, Ranked, Physique Duels, Profile, and Collectibles. The chapters reuse these clips and their longer variants. A feature that cannot be shown truthfully in the current app is reported, not faked.
- **Web output:** portrait recordings scaled for web playback, silent, encoded for every major browser, kept small enough to stream instantly, plus a poster still for each. A typed catalog lists every clip with its feature, length, and size so the site never references a missing file.

## Hero Film

- **Approved frames:** the first frame shows the classical marble statue looking down at a green-screen phone, with the head at the upper left, the phone near the center, and the right side empty. The last frame shows the phone upright and centered, held by the marble hand, with the head out of focus at the left. Both are generated with `fgen` and stored with their prompts.
- **Single generation:** Kling 4.0 image-to-video with both frames, ten seconds at 1080p and 16:9. It cost 10 credits. The user first asked for Seedance 2.5. Higgsfield rejected both Seedance 2.5 and Seedance 2.0 before charging, because they require a Pro plan and the account is on Starter, so the user approved Kling 4.0. The prompt and job record are stored beside the frames. The first take was accepted, and no retries were made.
- **Post-processing:**
  - Clamp the background to true black so it matches the page exactly.
  - Find the green screen in every frame and turn it into a clean, soft-edged transparent hole, so marble fingers that overlap it stay in front.
  - Remove any green tint from the marble.
  - Track the four corners of the screen in every frame, so recordings can be placed in exact perspective.
  - Export web-ready frame sequences for desktop and phones, a poster that already shows a real app screen, and the per-frame screen corners.
- **Stillness:** if the first seconds of the film are calm enough, they become the hero's seamless idle loop.
- **Darker regeneration:** at the user's request, the approved frames were relit with `fgen` into a darker low-key mood with the same composition. The film was then generated once more with Kling 4.0 for 10 credits. This dark take is the film on the site.
- **Depth film:** a matching per-frame depth film was generated once with Depth Anything Video (VDA-Large, 15.07 credits). It drives the cursor relighting and is exported beside the frame sequences at half resolution.

## Talos 3D Model

- **Identity:** the existing mascot. A bald ivory-marble athlete with a fluted lower-face mask, a black scarf, black shorts, orange wrist wraps, and an orange belt. It is the same character as the Ranked hero art and the welcome email.
- **Preparation:** consistent front, three-quarter, side, and back reference views in a neutral standing pose are generated with `fgen` from the original art and approved before any credits are spent.
- **Single generation:** one image-to-3D generation on Higgsfield, at no more than 34 credits, with textures. The result is cleaned, decimated, and compressed for the web while preserving the silhouette, the mask, and the orange accents.
- **Fallback:** if the generated model is not good enough, the chapter uses a layered 2.5D rendition built from the approved reference views instead of spending more credits without asking the user.

## Generated Stills

- **Tool:** `fgen`, which runs on the user's ChatGPT subscription and spends no Higgsfield credits.
- **Art direction:** pure black backgrounds that disappear into the page; white marble; low-key cinematic light with a warm key and a cool rim; orange accent light; no baked-in text, interface, or watermarks; and grain that matches the film.
- **Brand marks:** platform logos (Instagram, TikTok, YouTube, X, Facebook) and the Tmax mark are never generated. Real vector marks are composited by us onto generated, blank forms.
- **Layers:** parallax scenes are produced as separate depth layers, either on pure black or cut out with clean edges, so the site can move them independently.

## Credit Budget (Higgsfield)

| Item | Credits | Status |
|---|---|---|
| Starting balance | 270 | — |
| Hero film, Kling 4.0, 10 s at 1080p | 10 | First take, superseded by the darker take |
| Talos image-to-3D, Tripo H3.1 | 18 | Generated once |
| Darker hero film, Kling 4.0 | 10 | Generated once, on the site |
| Depth film, Depth Anything Video VDA-Large | 15.07 | Generated once, on the site |
| Remaining | 216.93 | Not spent without the user's approval |

## Storage

- Sources, prompts, candidates, and job records live under `genesis/REFERENCE/website/`.
- Web-ready outputs live inside the website's public media folders, compressed and named by purpose.

## Dependencies

- The native app builds and runs in the simulator.
- The authenticated `higgsfield` and `fgen` command-line tools.
- The original mascot art (`TimeMaster/Resources/Assets.xcassets/RankedHero.imageset/art.png`, `genesis/REFERENCE/tmax-branding/email-welcome-mascot.png`).
