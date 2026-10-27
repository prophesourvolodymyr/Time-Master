"use client";

import type { KeyboardEvent, Ref } from "react";
import type { AppClipId } from "@/content/app-clips";
import { AppClip } from "@/components/media";
import { CardSurface } from "@/components/ui";
import type { Chapter } from "@/lib/site";
import { chapterIcons } from "@/sections/chapters/shared/chapter-icons";
import styles from "./choice.module.css";

export type PlatformTileProps = {
  chapter: Chapter;
  clip: AppClipId;
  focused: boolean;
  upNext: boolean;
  ref?: Ref<HTMLButtonElement>;
  onChoose: () => void;
  onKeyDown: (event: KeyboardEvent<HTMLButtonElement>) => void;
};

export function PlatformTile({ chapter, clip, focused, upNext, ref, onChoose, onKeyDown }: PlatformTileProps) {
  const Icon = chapterIcons[chapter.id];
  return (
    <CardSurface
      as="button"
      ref={ref}
      type="button"
      emphasized={focused}
      className={styles.tile}
      data-focused={focused || undefined}
      aria-label={`${chapter.title}. ${chapter.pitch}`}
      onClick={onChoose}
      onKeyDown={onKeyDown}
    >
      <span className={styles.preview} aria-hidden="true">
        <AppClip id={clip} active={focused} />
      </span>
      {upNext ? <span className={styles.upNext}>Up next</span> : null}
      <span className={styles.pedestal} aria-hidden="true">
        <Icon weight="bold" />
      </span>
      <span className="relative font-display text-[clamp(18px,1.9vw,26px)] leading-none font-black tracking-tight">{chapter.title}</span>
      <span className="relative hidden max-w-[24ch] text-[13px] leading-snug text-ink-2 md:block">{chapter.pitch}</span>
    </CardSurface>
  );
}
