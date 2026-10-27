import type { AppClipId } from "./app-clips";

export type FilmFeature = {
  word: string;
  clip: AppClipId;
};

export const filmFeatures: readonly FilmFeature[] = [
  { word: "Workout", clip: "workout-player" },
  { word: "Timer", clip: "timer" },
  { word: "Builder", clip: "builder" },
  { word: "Database", clip: "database" },
  { word: "Map", clip: "map-recording" },
  { word: "Routes", clip: "routes" },
  { word: "AI Coach", clip: "ai-coach" },
  { word: "Agents", clip: "agent-settings" },
  { word: "Analytics", clip: "analytics" },
  { word: "Streaks", clip: "streaks" },
  { word: "Schedule", clip: "schedule" },
  { word: "Music", clip: "music" },
  { word: "Ranked", clip: "ranked" },
  { word: "Duels", clip: "duels" },
  { word: "Profile", clip: "profile" },
  { word: "Collectibles", clip: "collectibles" },
];

export const editWords: readonly string[] = [...filmFeatures.map((feature) => feature.word), "Everything"];
