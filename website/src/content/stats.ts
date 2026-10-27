export type StatMode = "person" | "collection";

export type StatFigure = {
  value: number;
  prefix?: string;
  suffix?: string;
  plus?: boolean;
  text?: string;
};

export type StatReveal = "rise" | "iris" | "wipe" | "tilt" | "zoom" | "slide";

export type StatSize = "hero" | "tall" | "wide" | "banner" | "regular";

export type StatOutcome = "Saved" | "Collected" | "Made" | "Gained";

export type StatId = "nft" | "muscle" | "procrastination" | "subscriptions" | "rivals" | "community" | "main-character" | "database";

export type Stat = {
  id: StatId;
  label: string;
  outcome: StatOutcome;
  image: { src: string; width: number; height: number };
  size: StatSize;
  reveal: StatReveal;
  accent?: boolean;
  figures: Record<StatMode, StatFigure>;
};

export const statModes: readonly { value: StatMode; label: string }[] = [
  { value: "person", label: "Per person" },
  { value: "collection", label: "Collection" },
];

const landscape = { width: 1200, height: 800 };

export const stats: readonly Stat[] = [
  {
    id: "nft",
    label: "NFT money",
    outcome: "Made",
    image: { src: "/media/stats/nft.webp", ...landscape },
    size: "hero",
    reveal: "iris",
    accent: true,
    figures: { person: { value: 0, text: "$10–150" }, collection: { value: 15_000_000, prefix: "$" } },
  },
  {
    id: "muscle",
    label: "Muscle",
    outcome: "Gained",
    image: { src: "/media/stats/muscle.webp", ...landscape },
    size: "regular",
    reveal: "zoom",
    figures: { person: { value: 6, suffix: " lb" }, collection: { value: 558_848, suffix: " lb" } },
  },
  {
    id: "procrastination",
    label: "Workout procrastination",
    outcome: "Saved",
    image: { src: "/media/stats/procrastination.webp", width: 800, height: 1200 },
    size: "tall",
    reveal: "wipe",
    figures: { person: { value: 312, suffix: " h" }, collection: { value: 55_000_000, suffix: " h" } },
  },
  {
    id: "subscriptions",
    label: "Useless subscriptions",
    outcome: "Saved",
    image: { src: "/media/stats/subscriptions.webp", ...landscape },
    size: "regular",
    reveal: "tilt",
    figures: { person: { value: 480, prefix: "$" }, collection: { value: 150_000_000, prefix: "$" } },
  },
  {
    id: "rivals",
    label: "Ranked rivals",
    outcome: "Collected",
    image: { src: "/media/stats/rivals.webp", ...landscape },
    size: "regular",
    reveal: "slide",
    figures: { person: { value: 4 }, collection: { value: 5_775 } },
  },
  {
    id: "community",
    label: "Fitness community",
    outcome: "Collected",
    image: { src: "/media/stats/community.webp", ...landscape },
    size: "wide",
    reveal: "rise",
    figures: { person: { value: 38 }, collection: { value: 100_000, plus: true } },
  },
  {
    id: "main-character",
    label: "Main-character energy",
    outcome: "Gained",
    image: { src: "/media/stats/main-character.webp", ...landscape },
    size: "regular",
    reveal: "zoom",
    accent: true,
    figures: { person: { value: 100, suffix: "%" }, collection: { value: 4_774_774 } },
  },
  {
    id: "database",
    label: "Database of exercises",
    outcome: "Collected",
    image: { src: "/media/stats/database.webp", ...landscape },
    size: "banner",
    reveal: "wipe",
    figures: { person: { value: 500, plus: true }, collection: { value: 500, plus: true } },
  },
];
