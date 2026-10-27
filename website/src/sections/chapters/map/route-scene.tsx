"use client";

import { useRef } from "react";
import Image from "next/image";
import { GlassSurface } from "@/components/ui";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";

const route =
  "M118 430 C210 380 300 392 380 452 S520 560 600 556 S760 520 840 590 S960 760 1010 820 C1046 866 1012 912 960 900 C880 882 860 800 800 760 S680 690 640 640 C610 600 560 520 520 470 S440 330 360 300";

const totalKm = 8.42;
const totalSeconds = 42 * 60 + 18;

function clock(seconds: number) {
  const whole = Math.round(seconds);
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

export function RouteScene() {
  const rootRef = useRef<HTMLDivElement>(null);
  const distanceRef = useRef<HTMLSpanElement>(null);
  const timeRef = useRef<HTMLSpanElement>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      const write = (progress: number) => {
        if (distanceRef.current) distanceRef.current.textContent = (totalKm * progress).toFixed(2);
        if (timeRef.current) timeRef.current.textContent = clock(totalSeconds * progress);
      };
      if (reducedMotion) {
        write(1);
        return;
      }
      const timeline = gsap.timeline({
        defaults: { ease: "none" },
        scrollTrigger: {
          trigger: rootRef.current,
          start: "top top",
          end: "+=180%",
          pin: true,
          scrub: 0.5,
          onUpdate: (self) => write(self.progress),
        },
      });
      timeline.fromTo("[data-route]", { drawSVG: "0%" }, { drawSVG: "100%", duration: 1 }, 0);
      timeline.to("[data-runner]", { motionPath: { path: "[data-route]", align: "[data-route]", alignOrigin: [0.5, 0.5] }, duration: 1 }, 0);
      timeline.fromTo("[data-map]", { scale: 1.18, rotate: -4 }, { scale: 1, rotate: 0, duration: 1 }, 0);
    },
    { scope: rootRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className="relative flex min-h-dvh items-center justify-center overflow-clip px-5 py-24">
      <div data-map className="absolute inset-0 grid place-items-center" aria-hidden="true">
        <div className="relative aspect-square w-[max(100vw,100dvh)] [mask-image:radial-gradient(closest-side,#000_62%,transparent)]">
          <Image src="/media/chapters/map/night-map.webp" alt="" fill sizes="100vmax" />
          <svg viewBox="0 0 1254 1254" className="absolute inset-0 size-full">
            <path d={route} fill="none" stroke="rgb(255 106 0 / 0.18)" strokeWidth="18" strokeLinecap="round" />
            <path data-route d={route} fill="none" stroke="#ff6a00" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" />
            <circle data-runner r="13" fill="#fff" stroke="#ff6a00" strokeWidth="6" />
          </svg>
        </div>
      </div>
      <div className="relative flex flex-col items-center gap-8 text-center">
        <h3 className="text-display text-[clamp(48px,8vw,128px)] drop-shadow-[0_6px_30px_rgb(0_0_0/0.8)]">
          Every run, <span className="text-accent">drawn live.</span>
        </h3>
        <GlassSurface className="grid grid-cols-3 gap-6 rounded-card px-6 py-4 text-left md:gap-10 md:px-8">
          <span className="flex flex-col">
            <span className="text-[12px] text-ink-2">Distance</span>
            <span className="font-display text-[clamp(22px,2.6vw,34px)] font-black tabular">
              <span ref={distanceRef}>{totalKm.toFixed(2)}</span> km
            </span>
          </span>
          <span className="flex flex-col">
            <span className="text-[12px] text-ink-2">Time</span>
            <span ref={timeRef} className="font-display text-[clamp(22px,2.6vw,34px)] font-black tabular">
              {clock(totalSeconds)}
            </span>
          </span>
          <span className="flex flex-col">
            <span className="text-[12px] text-ink-2">Pace</span>
            <span className="font-display text-[clamp(22px,2.6vw,34px)] font-black tabular">5:01 /km</span>
          </span>
        </GlassSurface>
      </div>
    </div>
  );
}
