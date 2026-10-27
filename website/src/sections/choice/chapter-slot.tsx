"use client";

import { useRef, type ComponentType } from "react";
import { useChapter } from "@/components/providers/chapter";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { ScrollTrigger, useGSAP } from "@/lib/gsap";
import type { ChapterId } from "@/lib/site";
import { AiChapter } from "@/sections/chapters/ai";
import { BuilderChapter } from "@/sections/chapters/builder";
import { MapChapter } from "@/sections/chapters/map";
import { SocialChapter } from "@/sections/chapters/social";
import styles from "./choice.module.css";

const views: Record<ChapterId, ComponentType> = {
  ai: AiChapter,
  social: SocialChapter,
  builder: BuilderChapter,
  map: MapChapter,
};

export function ChapterSlot() {
  const slotRef = useRef<HTMLDivElement>(null);
  const { chapter, request } = useChapter();
  const { scrollTo } = useSmoothScroll();
  const View = views[chapter];

  useGSAP(
    () => {
      const frame = requestAnimationFrame(() => {
        ScrollTrigger.sort();
        ScrollTrigger.refresh();
        if (!request?.scroll) return;
        scrollTo(request.fromY, { immediate: true });
        scrollTo("#chapter", {
          duration: 1.1,
          onComplete: () => {
            const top = slotRef.current ? slotRef.current.getBoundingClientRect().top + window.scrollY : window.scrollY;
            if (Math.abs(window.scrollY - top) > 4) scrollTo("#chapter", { immediate: true });
          },
        });
      });
      return () => cancelAnimationFrame(frame);
    },
    { scope: slotRef, dependencies: [chapter, request?.sequence], revertOnUpdate: true },
  );

  return (
    <div id="chapter" ref={slotRef} className={styles.slot}>
      <div key={chapter} className="motion-safe:animate-[chapter-in_700ms_ease-out]">
        <View />
      </div>
    </div>
  );
}
