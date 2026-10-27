import { appClips, type AppClip, type AppClipId } from "./app-clips";

const standIns: Partial<Record<AppClipId, AppClipId>> = {
  "ai-coach": "database",
  "agent-settings": "home",
  "ai-long": "builder",
  analytics: "home",
  streaks: "home",
  schedule: "home",
  music: "workout-player",
  ranked: "timer",
  duels: "workout-player",
  profile: "home",
  collectibles: "home",
  "social-long": "home",
  "builder-long": "builder",
  "map-long": "routes",
};

export function resolveClip(id: AppClipId): AppClip | null {
  const recorded = appClips[id];
  if (recorded) return recorded;
  const standIn = standIns[id];
  return standIn ? (appClips[standIn] ?? null) : null;
}
