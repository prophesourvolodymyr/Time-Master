"use client";

import { useRef } from "react";
import { BarbellIcon, PauseIcon, ShuffleIcon, TimerIcon } from "@phosphor-icons/react";
import { CardSurface } from "@/components/ui";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";

const rows = [
  { icon: TimerIcon, name: "Warm-up", detail: "3:00", timed: true },
  { icon: BarbellIcon, name: "Push-ups", detail: "4 × 12", timed: true },
  { icon: ShuffleIcon, name: "Core bundle", detail: "Plank · Hollow hold · V-ups", timed: false },
  { icon: PauseIcon, name: "Rest", detail: "0:45", timed: true },
  { icon: BarbellIcon, name: "Pistol squats", detail: "3 × 8 each leg", timed: true },
];

const scatter = [
  { x: -62, y: -34, rotate: -14 },
  { x: 58, y: -42, rotate: 11 },
  { x: -54, y: 38, rotate: 9 },
  { x: 64, y: 30, rotate: -10 },
  { x: -8, y: 64, rotate: 6 },
];

export function BuildStack() {
  const rootRef = useRef<HTMLDivElement>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      if (reducedMotion) return;
      const cards = gsap.utils.toArray<HTMLElement>("[data-build-row]");
      const timeline = gsap.timeline({
        scrollTrigger: { trigger: rootRef.current, start: "top top", end: "+=140%", pin: true, scrub: 0.6 },
      });
      cards.forEach((card, index) => {
        const from = scatter[index % scatter.length];
        timeline.fromTo(
          card,
          { xPercent: from.x * 4, yPercent: from.y * 6, rotate: from.rotate, autoAlpha: 0 },
          { xPercent: 0, yPercent: 0, rotate: 0, autoAlpha: 1, ease: "power3.out", duration: 1 },
          index * 0.35,
        );
      });
      timeline.fromTo("[data-build-title]", { autoAlpha: 0.15, scale: 0.92 }, { autoAlpha: 1, scale: 1, duration: 1 }, 0);
    },
    { scope: rootRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className="flex min-h-dvh flex-col items-center justify-center gap-10 overflow-clip px-5 py-24">
      <h3 data-build-title className="text-display text-center text-[clamp(48px,8vw,128px)]">
        Build it in <span className="text-accent">seconds.</span>
      </h3>
      <ol className="flex w-[min(100%,460px)] flex-col gap-3" aria-label="An example workout built in Tmax">
        {rows.map(({ icon: Icon, name, detail, timed }) => (
          <CardSurface as="li" key={name} data-build-row emphasized={timed} flat={!timed} className="flex items-center gap-4 px-5 py-4">
            <span
              className={timed ? "grid size-10 place-items-center rounded-chip bg-accent text-black" : "grid size-10 place-items-center rounded-chip bg-white text-black"}
              aria-hidden="true"
            >
              <Icon size={20} weight="bold" />
            </span>
            <span className="flex flex-1 flex-col">
              <span className="font-display text-[17px] font-black">{name}</span>
              <span className="text-[13px] text-ink-2">{detail}</span>
            </span>
          </CardSurface>
        ))}
      </ol>
    </div>
  );
}
