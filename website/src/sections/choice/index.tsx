"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import type { AppClipId } from "@/content/app-clips";
import { useChapter } from "@/components/providers/chapter";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import { chapters, type ChapterId } from "@/lib/site";
import { ChapterSlot } from "./chapter-slot";
import { DownloadBand } from "./download-band";
import { PlatformTile } from "./platform-tile";
import styles from "./choice.module.css";

const previewClips: Record<ChapterId, AppClipId> = {
  ai: "ai-coach",
  social: "social-long",
  builder: "builder",
  map: "map-recording",
};

const arrowSteps: Record<string, number> = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };

export function ChoiceSection() {
  const stageRef = useRef<HTMLDivElement>(null);
  const tileRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const [scrollFocus, setScrollFocus] = useState(-1);
  const { chapter, selectChapter } = useChapter();
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      if (reducedMotion) return;
      ScrollTrigger.create({
        trigger: stageRef.current,
        start: "top top",
        end: () => `+=${window.innerHeight * 2.4}`,
        pin: true,
        onUpdate: (self) => {
          const step = Math.min(chapters.length, Math.floor(self.progress * (chapters.length + 1)));
          setScrollFocus(step < chapters.length ? step : -1);
        },
        onLeave: () => setScrollFocus(-1),
        onLeaveBack: () => setScrollFocus(-1),
      });
      gsap.from("[data-hub-enter]", {
        yPercent: 40,
        autoAlpha: 0,
        stagger: 0.09,
        duration: 1.1,
        ease: "expo.out",
        scrollTrigger: { trigger: stageRef.current, start: "top 75%", toggleActions: "play none none reverse" },
      });
    },
    { scope: stageRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  const focusedId = scrollFocus >= 0 ? chapters[scrollFocus].id : chapter;

  const moveFocus = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const step = arrowSteps[event.key];
    if (!step) return;
    event.preventDefault();
    tileRefs.current[(index + step + chapters.length) % chapters.length]?.focus();
  };

  return (
    <section id="choose" aria-labelledby="choose-title">
      <div ref={stageRef} className={styles.stage}>
        <h2 id="choose-title" className="text-display text-center text-[clamp(40px,6vw,96px)]" data-hub-enter>
          Pick your obsession.
        </h2>
        <div className={styles.tiles} data-hub-enter>
          {chapters.map((item, index) => (
            <PlatformTile
              key={item.id}
              ref={(element) => {
                tileRefs.current[index] = element;
              }}
              chapter={item}
              clip={previewClips[item.id]}
              focused={item.id === focusedId}
              upNext={item.id === chapter}
              onChoose={() => selectChapter(item.id, { scroll: true })}
              onKeyDown={(event) => moveFocus(event, index)}
            />
          ))}
        </div>
        <DownloadBand />
      </div>
      <ChapterSlot />
    </section>
  );
}
