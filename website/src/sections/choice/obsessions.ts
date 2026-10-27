import { DevicesIcon, type Icon } from "@phosphor-icons/react";
import type { AppClipId } from "@/content/app-clips";
import type { ChapterId } from "@/lib/site";
import { chapterIcons } from "@/sections/chapters/shared/chapter-icons";

export type Obsession = {
  label: string;
  clip: AppClipId;
  chapter: ChapterId | null;
  icon: Icon;
};

export const obsessions: readonly Obsession[] = [
  { label: "AI Coach", clip: "ai-coach", chapter: "ai", icon: chapterIcons.ai },
  { label: "Social Media", clip: "social-long", chapter: "social", icon: chapterIcons.social },
  { label: "Workout Builder", clip: "builder", chapter: "builder", icon: chapterIcons.builder },
  { label: "Map", clip: "map-recording", chapter: "map", icon: chapterIcons.map },
  { label: "Crossplatform", clip: "workout-player", chapter: null, icon: DevicesIcon },
];

export const familyIndex = obsessions.findIndex((item) => item.chapter === null);
