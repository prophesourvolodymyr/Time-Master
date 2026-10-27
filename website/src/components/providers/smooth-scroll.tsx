"use client";

import { createContext, useContext, useEffect, useMemo, useRef, type ReactNode } from "react";
import Lenis from "lenis";
import "lenis/dist/lenis.css";
import { gsap, ScrollTrigger } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";

export type ScrollTarget = string | number | HTMLElement;

export type ScrollToOptions = {
  duration?: number;
  offset?: number;
  immediate?: boolean;
  lock?: boolean;
  onComplete?: () => void;
};

export type SmoothScroll = {
  scrollTo: (target: ScrollTarget, options?: ScrollToOptions) => void;
  stop: () => void;
  start: () => void;
  isGliding: () => boolean;
};

const SmoothScrollContext = createContext<SmoothScroll | null>(null);

const glideEasing = (t: number) => (t < 0.5 ? 16 * t ** 5 : 1 - (-2 * t + 2) ** 5 / 2);

export function SmoothScrollProvider({ children }: { children: ReactNode }) {
  const reducedMotion = usePrefersReducedMotion();
  const lenisRef = useRef<Lenis | null>(null);
  const glidingRef = useRef(false);

  useEffect(() => {
    const lenis = new Lenis({
      lerp: reducedMotion ? 1 : 0.1,
      smoothWheel: !reducedMotion,
      anchors: false,
      autoRaf: false,
      stopInertiaOnNavigate: true,
    });
    const tick = (seconds: number) => lenis.raf(seconds * 1000);
    lenis.on("scroll", ScrollTrigger.update);
    gsap.ticker.add(tick);
    gsap.ticker.lagSmoothing(0);
    lenisRef.current = lenis;
    return () => {
      gsap.ticker.remove(tick);
      lenis.destroy();
      lenisRef.current = null;
    };
  }, [reducedMotion]);

  const value = useMemo<SmoothScroll>(
    () => ({
      scrollTo(target, options = {}) {
        const destination = typeof target === "string" ? document.querySelector<HTMLElement>(target) : target;
        if (destination === null) return;
        const immediate = options.immediate ?? reducedMotion;
        const lenis = lenisRef.current;
        if (!lenis) {
          const top = typeof destination === "number" ? destination : destination.getBoundingClientRect().top + window.scrollY;
          window.scrollTo({ top: top + (options.offset ?? 0), behavior: immediate ? "auto" : "smooth" });
          options.onComplete?.();
          return;
        }
        glidingRef.current = !immediate;
        lenis.scrollTo(destination, {
          offset: options.offset ?? 0,
          duration: options.duration ?? 1.2,
          easing: glideEasing,
          immediate,
          lock: options.lock ?? false,
          force: true,
          onComplete: () => {
            glidingRef.current = false;
            options.onComplete?.();
          },
        });
      },
      stop: () => lenisRef.current?.stop(),
      start: () => lenisRef.current?.start(),
      isGliding: () => glidingRef.current,
    }),
    [reducedMotion],
  );

  return <SmoothScrollContext.Provider value={value}>{children}</SmoothScrollContext.Provider>;
}

export function useSmoothScroll() {
  const context = useContext(SmoothScrollContext);
  if (!context) throw new Error("useSmoothScroll must be used inside SmoothScrollProvider");
  return context;
}
