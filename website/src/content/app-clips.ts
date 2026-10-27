export type AppClipId =
  | "home"
  | "workout-player"
  | "timer"
  | "builder"
  | "database"
  | "map-recording"
  | "routes"
  | "ai-coach"
  | "agent-settings"
  | "analytics"
  | "streaks"
  | "schedule"
  | "music"
  | "ranked"
  | "duels"
  | "profile"
  | "collectibles"
  | "builder-long"
  | "map-long"
  | "ai-long"
  | "social-long";

export type AppClip = {
  id: AppClipId;
  feature: string;
  src: string;
  poster: string;
  width: number;
  height: number;
  duration: number;
};

export const appClips: Partial<Record<AppClipId, AppClip>> = {};
