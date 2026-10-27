import type { AppClipId } from "@/content/app-clips";
import type { ChapterId } from "@/lib/site";

export type Obsession = {
  label: string;
  clip: AppClipId;
  chapter: ChapterId;
};

export const obsessions: readonly Obsession[] = [
  { label: "Map", clip: "map-recording", chapter: "map" },
  { label: "Routes", clip: "routes", chapter: "map" },
  { label: "Interval Timer", clip: "timer", chapter: "builder" },
  { label: "Workout Builder", clip: "builder", chapter: "builder" },
  { label: "Exercise Library", clip: "database", chapter: "builder" },
  { label: "Duels", clip: "duels", chapter: "social" },
  { label: "Social Media", clip: "social-long", chapter: "social" },
  { label: "AI Coach", clip: "ai-coach", chapter: "ai" },
];
