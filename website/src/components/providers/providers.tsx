"use client";

import type { ReactNode } from "react";
import { InstallProvider } from "@/components/install/install-sheet";
import { ChapterProvider } from "./chapter";
import { ImmersiveProvider } from "./immersive";
import { SmoothScrollProvider } from "./smooth-scroll";

export function Providers({ children }: { children: ReactNode }) {
  return (
    <SmoothScrollProvider>
      <InstallProvider>
        <ChapterProvider>
          <ImmersiveProvider>{children}</ImmersiveProvider>
        </ChapterProvider>
      </InstallProvider>
    </SmoothScrollProvider>
  );
}
