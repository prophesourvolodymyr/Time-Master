"use client";

import { useRef, type ReactNode } from "react";
import { useChapter } from "@/components/providers/chapter";
import { GlassSurface, SelectionButton } from "@/components/ui";
import { ScrollTrigger, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import { chapters, type ChapterId } from "@/lib/site";
import { chapterIcons } from "./chapter-icons";

export type ChapterShellProps = {
  id: ChapterId;
  children: ReactNode;
};

export function ChapterShell({ id, children }: ChapterShellProps) {
  const rootRef = useRef<HTMLElement>(null);
  const { selectChapter } = useChapter();
  const reducedMotion = usePrefersReducedMotion();
  const chapter = chapters.find((item) => item.id === id);

  useGSAP(
    () => {
      if (reducedMotion) return;
      const body = rootRef.current?.querySelector<HTMLElement>("[data-chapter-body]");
      if (!body) return;
      ScrollTrigger.create({
        trigger: "[data-chapter-outro]",
        start: "top bottom",
        end: "bottom top",
        onUpdate: (self) => {
          body.style.opacity = String(1 - self.progress ** 2);
        },
      });
    },
    { scope: rootRef, dependencies: [reducedMotion] },
  );

  return (
    <article ref={rootRef} aria-labelledby={`chapter-${id}`} className="relative">
      <h2 id={`chapter-${id}`} className="sr-only">
        {chapter?.title}
      </h2>
      <div className="pointer-events-none sticky top-[calc(var(--nav-height)+8px)] z-30 flex justify-center px-4">
        <GlassSurface as="nav" aria-label="Choose a story" className="pointer-events-auto flex gap-1 rounded-[22px] p-1">
          {chapters.map((item) => {
            const Icon = chapterIcons[item.id];
            return (
              <SelectionButton
                key={item.id}
                selected={item.id === id}
                aria-label={item.title}
                className="!min-h-10 !px-3 !text-[14px] !shadow-none"
                onClick={() => selectChapter(item.id, { scroll: true })}
              >
                <Icon size={18} weight="bold" aria-hidden="true" />
                <span className="hidden sm:inline">{item.title}</span>
              </SelectionButton>
            );
          })}
        </GlassSurface>
      </div>
      <div data-chapter-body>{children}</div>
      <div data-chapter-outro aria-hidden="true" className="h-[40dvh]" />
    </article>
  );
}
