import { appClips, type AppClipId } from "./app-clips";

export type FilmFeature = {
  word: string;
  clip: AppClipId;
};

const allFeatures: readonly FilmFeature[] = [
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

export const filmFeatures = allFeatures.filter((feature) => appClips[feature.clip]);

export const featureWords: readonly string[] = allFeatures.map((feature) => feature.word);

export const editWords: readonly string[] = [...featureWords, "Everything"];
