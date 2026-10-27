import { useCallback } from "react";
import { useChapter } from "@/components/providers/chapter";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import type { ChapterId } from "@/lib/site";

export type NavLink = { label: string; chapter: ChapterId } | { label: string; target: string };

export const navLinks: readonly NavLink[] = [
  { label: "AI", chapter: "ai" },
  { label: "Social", chapter: "social" },
  { label: "Builder", chapter: "builder" },
  { label: "Map", chapter: "map" },
  { label: "Stats", target: "#stats" },
];

export function useFollowLink() {
  const { selectChapter } = useChapter();
  const { scrollTo } = useSmoothScroll();
  return useCallback(
    (link: NavLink) => {
      if ("chapter" in link) selectChapter(link.chapter, { scroll: true });
      else scrollTo(link.target);
    },
    [selectChapter, scrollTo],
  );
}
