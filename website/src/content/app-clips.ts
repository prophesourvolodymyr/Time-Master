export type AppClipId = "home" | "workout-player" | "timer" | "builder" | "database" | "map-recording" | "routes" | "ai-coach" | "agent-settings" | "analytics" | "streaks" | "schedule" | "music" | "ranked" | "duels" | "profile" | "collectibles" | "builder-long" | "map-long" | "ai-long" | "social-long";

export type AppClip = { id: AppClipId; feature: string; src: string; poster: string; width: number; height: number; duration: number };

export const appClips: Partial<Record<AppClipId, AppClip>> = {
  "home": {
    id: "home",
    feature: "Home",
    src: "/media/app/home.mp4",
    poster: "/media/app/home.jpg",
    width: 720,
    height: 1566,
    duration: 9.43,
  },
  "workout-player": {
    id: "workout-player",
    feature: "Workout player",
    src: "/media/app/workout-player.mp4",
    poster: "/media/app/workout-player.jpg",
    width: 720,
    height: 1566,
    duration: 10.7,
  },
  "timer": {
    id: "timer",
    feature: "Interval timer",
    src: "/media/app/timer.mp4",
    poster: "/media/app/timer.jpg",
    width: 720,
    height: 1566,
    duration: 10.5,
  },
};
