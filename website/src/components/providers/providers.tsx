"use client";

import { useEffect, type ReactNode } from "react";
import { ScrollTrigger } from "@/lib/gsap";
import { ChapterProvider } from "./chapter";
import { ImmersiveProvider } from "./immersive";
import { SmoothScrollProvider } from "./smooth-scroll";

export function Providers({ children }: { children: ReactNode }) {
  useEffect(() => {
    const frame = requestAnimationFrame(() => {
      ScrollTrigger.sort();
      ScrollTrigger.refresh();
    });
    return () => cancelAnimationFrame(frame);
  }, []);

  return (
    <SmoothScrollProvider>
      <ChapterProvider>
        <ImmersiveProvider>{children}</ImmersiveProvider>
      </ChapterProvider>
    </SmoothScrollProvider>
  );
}
