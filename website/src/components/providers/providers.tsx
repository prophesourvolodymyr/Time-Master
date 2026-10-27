"use client";

import { useEffect, type ReactNode } from "react";
import { ScrollTrigger } from "@/lib/gsap";
import { ChapterProvider } from "./chapter";
import { ImmersiveProvider } from "./immersive";
import { SmoothScrollProvider } from "./smooth-scroll";

function useLayoutRefresh() {
  useEffect(() => {
    let timer = 0;
    let height = 0;
    const refresh = () => {
      ScrollTrigger.sort();
      ScrollTrigger.refresh();
      height = document.body.scrollHeight;
    };
    const observer = new ResizeObserver(() => {
      if (document.body.scrollHeight === height) return;
      window.clearTimeout(timer);
      timer = window.setTimeout(refresh, 150);
    });
    observer.observe(document.body);
    return () => {
      observer.disconnect();
      window.clearTimeout(timer);
    };
  }, []);
}

export function Providers({ children }: { children: ReactNode }) {
  useLayoutRefresh();

  return (
    <SmoothScrollProvider>
      <ChapterProvider>
        <ImmersiveProvider>{children}</ImmersiveProvider>
      </ChapterProvider>
    </SmoothScrollProvider>
  );
}
