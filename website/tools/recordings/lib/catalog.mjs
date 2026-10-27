import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { CATALOG_FILE, OUTPUT_DIR, TOOLS_DIR } from "./config.mjs";
import { CLIP_HEIGHT, CLIP_WIDTH, encodeClip } from "./encode.mjs";

/** Every planned clip id in delivery order, with the feature name the site shows. */
export const CLIP_FEATURES = {
  home: "Home",
  "workout-player": "Workout player",
  timer: "Interval timer",
  builder: "Workout builder",
  database: "Exercise database",
  "map-recording": "Map recording",
  routes: "Routes",
  "ai-coach": "AI Coach chat",
  "agent-settings": "Agent settings",
  analytics: "Analytics",
  streaks: "Streaks",
  schedule: "Schedule",
  music: "Music",
  ranked: "Ranked",
  duels: "Physique Duels",
  profile: "Profile",
  collectibles: "Collectibles",
  "builder-long": "Workout builder",
  "map-long": "Map recording",
  "ai-long": "AI Coach",
  "social-long": "Profile, Ranked and Collectibles",
};

const MANIFEST = path.join(TOOLS_DIR, "clips.json");

async function readManifest() {
  return existsSync(MANIFEST) ? JSON.parse(await readFile(MANIFEST, "utf8")) : {};
}

function render(manifest) {
  const ids = Object.keys(CLIP_FEATURES);
  const entries = ids
    .filter((id) => manifest[id] && existsSync(path.join(OUTPUT_DIR, `${id}.mp4`)))
    .map((id) => {
      const clip = {
        id,
        feature: CLIP_FEATURES[id],
        src: `/media/app/${id}.mp4`,
        poster: `/media/app/${id}.jpg`,
        width: CLIP_WIDTH,
        height: CLIP_HEIGHT,
        duration: manifest[id].duration,
      };
      const fields = Object.entries(clip).map(([key, value]) => `    ${key}: ${JSON.stringify(value)},`).join("\n");
      return `  ${JSON.stringify(id)}: {\n${fields}\n  },`;
    });
  return [
    `export type AppClipId = ${ids.map((id) => JSON.stringify(id)).join(" | ")};`,
    "",
    "export type AppClip = { id: AppClipId; feature: string; src: string; poster: string; width: number; height: number; duration: number };",
    "",
    entries.length ? `export const appClips: Partial<Record<AppClipId, AppClip>> = {\n${entries.join("\n")}\n};` : "export const appClips: Partial<Record<AppClipId, AppClip>> = {};",
    "",
  ].join("\n");
}

/** Records a delivered clip and regenerates `src/content/app-clips.ts` from every clip on disk. */
export async function updateCatalog(id, details) {
  const manifest = await readManifest();
  if (id) manifest[id] = details;
  await writeFile(MANIFEST, `${JSON.stringify(manifest, null, 2)}\n`);
  await mkdir(path.dirname(CATALOG_FILE), { recursive: true });
  await writeFile(CATALOG_FILE, render(manifest));
}

export async function storedTrim(id) {
  const entry = (await readManifest())[id];
  if (!entry?.trim) throw new Error(`No stored trim for ${id}; record it first.`);
  return entry.trim;
}

/** Encodes the trimmed span of a raw master into public/media/app and updates the catalog. */
export async function deliverClip(id, { raw, start, length }) {
  await mkdir(OUTPUT_DIR, { recursive: true });
  const result = await encodeClip({
    raw, start, duration: length,
    output: path.join(OUTPUT_DIR, `${id}.mp4`),
    poster: path.join(OUTPUT_DIR, `${id}.jpg`),
  });
  await updateCatalog(id, {
    duration: result.duration, bytes: result.bytes, recordedAt: new Date().toISOString(),
    trim: { raw: path.relative(TOOLS_DIR, raw), start: Number(start.toFixed(3)), length: Number(length.toFixed(3)) },
  });
  const perTenSeconds = ((result.bytes / result.duration) * 10) / 1e6;
  process.stdout.write(`  ✓ ${id}: ${result.duration} s, ${(result.bytes / 1e6).toFixed(2)} MB (${perTenSeconds.toFixed(2)} MB per 10 s)\n`);
  return result;
}
