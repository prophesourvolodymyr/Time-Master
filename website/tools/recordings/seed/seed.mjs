#!/usr/bin/env node
// Installs the demo data set into the dedicated recording simulator (never any other device).
import { existsSync } from "node:fs";
import { copyFile, mkdir, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { BUNDLE_ID, RAW_DIR, REPO_DIR, UDID } from "../lib/config.mjs";
import { plist } from "../lib/plist.mjs";
import { run, sleep } from "../lib/process.mjs";
import { appContainer, grantPrivacy, launchApp, terminateApp } from "../lib/sim.mjs";
import { MUSIC_TRACKS, buildDemo, musicFilename } from "./demo.mjs";

const SEED_DIR = path.dirname(fileURLToPath(import.meta.url));
export const ASSETS_DIR = path.join(RAW_DIR, "seed-assets");
const MARKERS = [".migration_complete", ".migration_v2_pages_complete", ".migration_page_kinds_complete", ".migration_page_types_complete", ".legacy_page_cache_clean"];
const DATA_FOLDERS = ["Workouts", "Exercises Database", "History", "Activities", "Routes", "profile", "ranked", "Media", "Music", "Backups", ".trash"];

const pretty = (value) => `${JSON.stringify(value, null, 2)}\n`;

async function writeJSON(file, value) {
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, pretty(value));
}

async function ensureAssets() {
  if (!existsSync(path.join(ASSETS_DIR, "square-rightSidePlank.jpg"))) {
    await run("python3", [path.join(SEED_DIR, "compose_assets.py"), REPO_DIR, ASSETS_DIR]);
  }
  await mkdir(path.join(ASSETS_DIR, "music"), { recursive: true });
  for (const track of MUSIC_TRACKS) {
    const file = path.join(ASSETS_DIR, "music", musicFilename(track));
    if (existsSync(file)) continue;
    await run("ffmpeg", [
      "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", `sine=frequency=${track.tone}:duration=${track.seconds}`,
      "-af", "volume=0.12", "-ac", "1", "-c:a", "aac", "-b:a", "24k", file,
    ]);
  }
}

/** A fresh install bootstraps its folders and migration markers on first launch. */
async function ensureBootstrapped(container) {
  if (existsSync(path.join(container, "Documents", "TimeMaster", "Config", ".migration_complete"))) return;
  await launchApp();
  await sleep(9_000);
  await terminateApp();
}

export async function seed({ now = new Date() } = {}) {
  await terminateApp();
  const container = await appContainer();
  await ensureBootstrapped(container);
  await ensureAssets();
  const demo = buildDemo(now);
  const documents = path.join(container, "Documents");
  const root = path.join(documents, "TimeMaster");

  for (const folder of DATA_FOLDERS) await rm(path.join(root, folder), { recursive: true, force: true });
  await rm(path.join(documents, "Photos"), { recursive: true, force: true });
  await rm(path.join(documents, "Music"), { recursive: true, force: true });
  for (const folder of DATA_FOLDERS) await mkdir(path.join(root, folder), { recursive: true });

  await writeJSON(path.join(root, "Config", "manifest.json"), demo.config);
  for (const marker of MARKERS) await writeFile(path.join(root, "Config", marker), "1");

  for (const page of demo.pages) {
    const folder = path.join(root, "Exercises Database", ...page.path);
    await writeJSON(path.join(folder, "manifest.json"), page.manifest);
    await writeFile(path.join(folder, "guide.md"), page.guide);
    for (const file of page.files) {
      await mkdir(path.dirname(path.join(folder, file.name)), { recursive: true });
      await copyFile(path.join(ASSETS_DIR, file.asset), path.join(folder, file.name));
    }
  }
  for (const workout of demo.workouts) await writeJSON(path.join(root, "Workouts", workout.id, "manifest.json"), workout);
  await writeFile(path.join(root, "History", "entries.jsonl"), demo.history.map((entry) => `${JSON.stringify(entry)}\n`).join(""));
  for (const activity of demo.activities) {
    await writeJSON(path.join(root, "Activities", activity.manifest.id, "manifest.json"), activity.manifest);
    await writeFile(path.join(root, "Activities", activity.manifest.id, "track.jsonl"), activity.track.map((point) => `${JSON.stringify(point)}\n`).join(""));
  }
  for (const route of demo.plannedRoutes) await writeJSON(path.join(root, "Routes", `${route.id}.json`), route);
  for (const result of demo.practice) await writeJSON(path.join(root, "ranked", "practice", `${result.id}.json`), result);
  await writeJSON(path.join(root, "profile", "local-profile.json"), demo.profile);

  await mkdir(path.join(documents, "Photos"), { recursive: true });
  for (const photo of demo.photos) await copyFile(path.join(ASSETS_DIR, photo), path.join(documents, "Photos", photo));
  await mkdir(path.join(documents, "Music"), { recursive: true });
  for (const track of MUSIC_TRACKS) {
    await copyFile(path.join(ASSETS_DIR, "music", musicFilename(track)), path.join(documents, "Music", musicFilename(track)));
  }
  for (const extra of demo.extraFiles ?? []) {
    await mkdir(path.dirname(path.join(documents, extra.path)), { recursive: true });
    await writeFile(path.join(documents, extra.path), extra.content);
  }

  // Through the simulator's cfprefsd (delete + import), never by editing the plist file: cfprefsd caches
  // the domain and would write stale keys (for example a saved workout-resume state) back over the file.
  const domain = path.join(container, "Library", "Preferences", BUNDLE_ID);
  const defaultsFile = path.join(RAW_DIR, "seed-defaults.plist");
  await writeFile(defaultsFile, plist(demo.defaults));
  await run("xcrun", ["simctl", "spawn", UDID, "defaults", "delete", domain]).catch(() => {});
  await run("xcrun", ["simctl", "spawn", UDID, "defaults", "import", domain, defaultsFile]);
  await grantPrivacy();
  return demo;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const demo = await seed();
  process.stdout.write(`Seeded ${demo.workouts.length} workouts, ${demo.pages.length} pages, ${demo.history.length} history entries, ${demo.activities.length} activities.\n`);
}
