import { useSyncExternalStore } from "react";

const reducedMotionQuery = "(prefers-reduced-motion: reduce)";

const subscribers = new Map<string, (onChange: () => void) => () => void>();

function subscribeTo(query: string) {
  let subscribe = subscribers.get(query);
  if (!subscribe) {
    subscribe = (onChange) => {
      const list = window.matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    };
    subscribers.set(query, subscribe);
  }
  return subscribe;
}

export function useMediaQuery(query: string, serverValue = false) {
  return useSyncExternalStore(
    subscribeTo(query),
    () => window.matchMedia(query).matches,
    () => serverValue,
  );
}

export function usePrefersReducedMotion() {
  return useMediaQuery(reducedMotionQuery);
}

export function prefersReducedMotion() {
  return typeof window !== "undefined" && window.matchMedia(reducedMotionQuery).matches;
}

export const ease = {
  out: "power3.out",
  inOut: "power3.inOut",
  expo: "expo.out",
  slide: "expo.inOut",
} as const;
