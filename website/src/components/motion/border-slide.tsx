"use client";

import { useRef, type ReactNode } from "react";
import clsx from "clsx";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";

export type BorderEdge = "top" | "bottom" | "left" | "right";

export type BorderSlideProps = {
  children: ReactNode;
  from?: BorderEdge;
  trigger?: "scroll" | "mount";
  delay?: number;
  duration?: number;
  className?: string;
  innerClassName?: string;
};

export const borderOffsets: Record<BorderEdge, gsap.TweenVars> = {
  top: { yPercent: -105 },
  bottom: { yPercent: 105 },
  left: { xPercent: -105 },
  right: { xPercent: 105 },
};

export function BorderSlide({
  children,
  from = "bottom",
  trigger = "scroll",
  delay = 0,
  duration = 1.1,
  className,
  innerClassName,
}: BorderSlideProps) {
  const outerRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      const scrollTrigger = trigger === "scroll" ? { trigger: outerRef.current, start: "top 90%", once: true } : undefined;
      const vars = reducedMotion ? { autoAlpha: 0, duration: 0.4 } : { ...borderOffsets[from], duration, ease: "expo.out" };
      gsap.from(innerRef.current, { ...vars, delay, scrollTrigger });
    },
    { scope: outerRef, dependencies: [reducedMotion, from, trigger, delay, duration] },
  );

  return (
    <div ref={outerRef} className={clsx("overflow-clip", className)}>
      <div ref={innerRef} className={innerClassName}>
        {children}
      </div>
    </div>
  );
}
