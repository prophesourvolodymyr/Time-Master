"use client";

import { useEffect, useRef, useState, type Ref } from "react";
import clsx from "clsx";
import { useImmersive } from "@/components/providers/immersive";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/gsap";
import type { TalosPose } from "./talos-pose";
import { TalosPoster } from "./talos-stage";
import styles from "./ai-chapter.module.css";

const flashes = [
  { at: 0.15, spin: 0.62, x: "24%" },
  { at: 0.55, spin: -0.85, x: "78%" },
  { at: 0.95, spin: 0.3, x: "38%" },
  { at: 1.3, spin: -0.22, x: "62%" },
];

export type StrobeIntroProps = {
  pose: TalosPose;
  reducedMotion: boolean;
  modelReady: boolean;
  sectionRef: Ref<HTMLElement>;
};

export function StrobeIntro({ pose, reducedMotion, modelReady, sectionRef }: StrobeIntroProps) {
  const pinRef = useRef<HTMLDivElement>(null);
  const flashRef = useRef<HTMLDivElement>(null);
  const readyRef = useRef(modelReady);
  const pendingRef = useRef<(() => void) | null>(null);
  const [strobing, setStrobing] = useState(false);
  useImmersive(strobing);

  useEffect(() => {
    readyRef.current = modelReady;
    if (modelReady) pendingRef.current?.();
  }, [modelReady]);

  useGSAP(
    (_, safe) => {
      const pin = pinRef.current;
      const flash = flashRef.current;
      if (reducedMotion || !pin || !flash || !safe) return;
      const lines = pin.querySelectorAll("[data-intro-line]");
      const sub = pin.querySelector("[data-intro-sub]");
      gsap.set(pose, { light: 0, flash: 0, spin: 0, float: 0.35 });
      gsap.set(lines, { yPercent: 105 });
      gsap.set(sub, { autoAlpha: 0, y: 24 });

      const strobe = gsap.timeline({
        paused: true,
        onStart: () => setStrobing(true),
        onComplete: () => setStrobing(false),
      });
      flashes.forEach(({ at, spin, x }) => {
        strobe
          .set(pose, { spin }, at - 0.02)
          .set(flash, { "--flash-x": x }, at - 0.02)
          .to(pose, { flash: 1, duration: 0.04, ease: "none" }, at)
          .to(pose, { flash: 0, duration: 0.26, ease: "power2.out" }, at + 0.04)
          .fromTo(flash, { opacity: 0.2 }, { opacity: 0, duration: 0.34, ease: "power2.out" }, at);
      });
      strobe
        .to(pose, { light: 1, spin: 0, float: 1, duration: 1.1, ease: "power2.inOut" }, 1.62)
        .to(lines, { yPercent: 0, duration: 1, ease: "expo.out", stagger: 0.16 }, 1.9)
        .to(sub, { autoAlpha: 1, y: 0, duration: 0.7, ease: "power3.out" }, 2.5);

      const finish = () => {
        pendingRef.current = null;
        if (strobe.progress() < 1) strobe.progress(1);
      };
      const begin = () => {
        pendingRef.current = null;
        if (strobe.progress() === 0 && !strobe.isActive()) strobe.play();
      };
      const request = safe(() => {
        if (strobe.progress() > 0 || pendingRef.current) return;
        if (readyRef.current) {
          begin();
          return;
        }
        setStrobing(true);
        pendingRef.current = begin;
        gsap.delayedCall(1.4, () => pendingRef.current?.());
      });
      const trigger = ScrollTrigger.create({
        trigger: pin.parentElement,
        start: "top 40%",
        end: "bottom top",
        onEnter: request,
        onLeave: finish,
        onEnterBack: finish,
      });
      if (trigger.progress >= 1) finish();
      else if (trigger.isActive) request();
      return () => {
        pendingRef.current = null;
        setStrobing(false);
        gsap.set(pose, { light: 1, flash: 0, spin: 0, float: 1 });
      };
    },
    { scope: pinRef, dependencies: [reducedMotion, pose], revertOnUpdate: true },
  );

  return (
    <section ref={sectionRef} className={clsx(styles.intro, reducedMotion && styles.introStill)}>
      <div ref={pinRef} className={styles.introPin}>
        <div ref={flashRef} className={styles.flash} aria-hidden="true" />
        <h3 className={styles.introTitle}>
          <span className={styles.mask}>
            <span data-intro-line className={styles.kicker}>
              Introducing
            </span>
          </span>
          <span className={styles.mask}>
            <span data-intro-line className={styles.name}>
              Talos
            </span>
          </span>
        </h3>
        {reducedMotion ? <TalosPoster className={styles.introPoster} /> : null}
        <p data-intro-sub className={styles.introSub}>
          Your AI agent, built into Tmax. It builds, it explains, and it asks before it touches anything.
        </p>
      </div>
    </section>
  );
}
