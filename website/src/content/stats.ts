export type StatMode = "person" | "collection";

export type StatFigure = {
  value: number;
  prefix?: string;
  suffix?: string;
  plus?: boolean;
  text?: string;
};

export type Stat = {
  label: string;
  outcome: string;
  joke: string;
  emphasized?: boolean;
  figures: Record<StatMode, StatFigure>;
};

export const statModes: readonly { value: StatMode; label: string }[] = [
  { value: "person", label: "Per person" },
  { value: "collection", label: "Collection" },
];

export const stats: readonly Stat[] = [
  {
    label: "Workout procrastination",
    outcome: "Saved",
    joke: "Every “I’ll start Monday”, cancelled.",
    figures: { person: { value: 312, suffix: " h" }, collection: { value: 55_000_000, suffix: " h" } },
  },
  {
    label: "Database of exercises",
    outcome: "Collected",
    joke: "Including at least 40 ways to hate leg day.",
    figures: { person: { value: 500, plus: true }, collection: { value: 500, plus: true } },
  },
  {
    label: "Useless subscriptions",
    outcome: "Saved",
    joke: "Five apps walked so one could run.",
    figures: { person: { value: 480, prefix: "$" }, collection: { value: 150_000_000, prefix: "$" } },
  },
  {
    label: "Fitness community",
    outcome: "Collected",
    joke: "Gym friends, minus the awkward small talk.",
    figures: { person: { value: 38 }, collection: { value: 100_000, plus: true } },
  },
  {
    label: "Ranked rivals",
    outcome: "Collected",
    joke: "They want your Elo. Let them try.",
    figures: { person: { value: 4 }, collection: { value: 5_775 } },
  },
  {
    label: "NFT money",
    outcome: "Made",
    joke: "Sweat in. Collectibles out.",
    emphasized: true,
    figures: { person: { value: 0, text: "$10–150" }, collection: { value: 15_000_000, prefix: "$" } },
  },
  {
    label: "Muscle",
    outcome: "Gained",
    joke: "About 93 elephants of pure gains.",
    figures: { person: { value: 6, suffix: " lb" }, collection: { value: 558_848, suffix: " lb" } },
  },
  {
    label: "Main-character energy",
    outcome: "Gained",
    joke: "Unit of measurement pending.",
    emphasized: true,
    figures: { person: { value: 100, suffix: "%" }, collection: { value: 4_774_774 } },
  },
];
