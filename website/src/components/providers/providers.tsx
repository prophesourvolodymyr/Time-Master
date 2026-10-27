"use client";

import type { ReactNode } from "react";
import { ChapterProvider } from "./chapter";
import { ImmersiveProvider } from "./immersive";
import { SmoothScrollProvider } from "./smooth-scroll";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <SmoothScrollProvider>
      <ChapterProvider>
        <ImmersiveProvider>{children}</ImmersiveProvider>
      </ChapterProvider>
    </SmoothScrollProvider>
  );
}
