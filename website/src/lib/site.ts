export type ChapterId = "ai" | "social" | "builder" | "map";

export type DownloadId = "appStore" | "googlePlay" | "ipa";

export type Download = {
  id: DownloadId;
  label: string;
  href?: string;
};

export type Chapter = {
  id: ChapterId;
  title: string;
  pitch: string;
};

function optionalUrl(value: string | undefined) {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

export const site = {
  name: "Tmax",
  title: "Tmax: A Fitness Everything App You Dreamed Of",
  description:
    "Workouts, timers, maps, an AI agent with its own username, and a fitness social feed in one app. Every new sign-up can win a free NFT worth $10 to $150.",
  url: optionalUrl(process.env.NEXT_PUBLIC_SITE_URL) ?? "http://localhost:3000",
  contactEmail: optionalUrl(process.env.NEXT_PUBLIC_CONTACT_EMAIL),
  promo: {
    range: "$10–150",
    sentence: "Every new sign-up gets a chance to win a free NFT worth $10 to $150.",
  },
} as const;

export const downloads: readonly Download[] = [
  { id: "appStore", label: "App Store", href: optionalUrl(process.env.NEXT_PUBLIC_APP_STORE_URL) },
  { id: "googlePlay", label: "Google Play", href: optionalUrl(process.env.NEXT_PUBLIC_GOOGLE_PLAY_URL) },
  { id: "ipa", label: "Install IPA", href: optionalUrl(process.env.NEXT_PUBLIC_IPA_URL) },
];

export const chapters: readonly Chapter[] = [
  { id: "ai", title: "AI", pitch: "Meet Talos, the coach that builds, plans and remembers." },
  { id: "social", title: "Social Media", pitch: "The feed where every post is a rep." },
  { id: "builder", title: "Workout Builder", pitch: "Drag, drop, done. Your workout in seconds." },
  { id: "map", title: "Map", pitch: "Every run and ride, drawn live on the map." },
];

const chapterIds = chapters.map((chapter) => chapter.id);

export function isChapterId(value: string): value is ChapterId {
  return (chapterIds as readonly string[]).includes(value);
}
