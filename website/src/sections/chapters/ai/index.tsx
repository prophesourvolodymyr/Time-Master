"use client";

import { ChapterShell } from "../shared/chapter-shell";
import { TalosStory } from "./talos-story";

export function AiChapter() {
  return (
    <ChapterShell id="ai">
      <TalosStory />
    </ChapterShell>
  );
}
