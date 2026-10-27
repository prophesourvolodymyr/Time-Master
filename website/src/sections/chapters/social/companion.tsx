"use client";

import { useRef, type CSSProperties } from "react";
import { TmaxMark } from "@/components/chrome/tmax-mark";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import styles from "./companion.module.css";

const edgeLayers = [1, 2, 3, 4, 5, 6, 7, 8];

function AppIcon() {
  return (
    <div className={styles.icon}>
      <span className={styles.glow} />
      {edgeLayers.map((layer) => (
        <span key={layer} className={styles.edge} style={{ "--layer": layer } as CSSProperties} />
      ))}
      <span className={styles.face}>
        <TmaxMark className={styles.mark} />
      </span>
      <span className={styles.sheen} data-sheen />
    </div>
  );
}

export type CompanionProps = {
  cue: string;
};

export function Companion({ cue }: CompanionProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      const root = rootRef.current;
      const trigger = root?.parentElement?.querySelector<HTMLElement>(cue);
      const exit = root?.querySelector<HTMLElement>("[data-exit]");
      const drop = root?.querySelector<HTMLElement>("[data-drop]");
      const float = root?.querySelector<HTMLElement>("[data-float]");
      const tilt = root?.querySelector<HTMLElement>("[data-tilt]");
      const sheen = root?.querySelector<HTMLElement>("[data-sheen]");
      if (!trigger || !exit || !drop || !float || !tilt || !sheen) return;

      if (reducedMotion) {
        gsap.set(drop, { autoAlpha: 0 });
        ScrollTrigger.create({
          trigger,
          start: "top 92%",
          end: "bottom top",
          onToggle: (self) => gsap.set(drop, { autoAlpha: self.isActive ? 1 : 0 }),
        });
        return;
      }

      gsap.set(drop, { yPercent: -420, rotationX: -55, rotationZ: -24, autoAlpha: 0 });
      const landing = gsap
        .timeline({ paused: true })
        .to(drop, { autoAlpha: 1, duration: 0.1 }, 0)
        .to(drop, { yPercent: 0, rotationX: 0, rotationZ: 0, duration: 1.15, ease: "elastic.out(1, 0.5)" }, 0);
      const bob = gsap.to(float, { yPercent: -8, rotationZ: 3, duration: 2.4, ease: "sine.inOut", yoyo: true, repeat: -1, paused: true });
      const pitch = gsap.quickTo(tilt, "rotationX", { duration: 0.7, ease: "power3" });
      const yaw = gsap.quickTo(tilt, "rotationY", { duration: 1.1, ease: "power3" });
      const settle = gsap.delayedCall(0.16, () => pitch(0)).pause();

      const glint = () => {
        const turn = Number(gsap.getProperty(tilt, "rotationY")) + Number(gsap.getProperty(float, "rotationZ")) * 2;
        sheen.style.setProperty("--glint", `${(42 - turn * 1.5).toFixed(1)}%`);
      };

      ScrollTrigger.create({
        trigger,
        start: "top 92%",
        end: "bottom top",
        onEnter: () => landing.play(),
        onLeaveBack: () => landing.reverse(),
        onToggle: (self) => {
          if (self.isActive) {
            bob.play();
            gsap.ticker.add(glint);
          } else {
            bob.pause();
            gsap.ticker.remove(glint);
          }
        },
        onUpdate: (self) => {
          pitch(gsap.utils.clamp(-24, 24, self.getVelocity() / -90));
          yaw(Math.sin(self.progress * Math.PI * 9) * 26);
          settle.restart(true);
        },
      });

      gsap.to(exit, {
        yPercent: -520,
        rotationX: 40,
        ease: "power2.in",
        scrollTrigger: { trigger, start: "bottom 85%", end: "bottom 15%", scrub: true },
      });

      return () => gsap.ticker.remove(glint);
    },
    { scope: rootRef, dependencies: [reducedMotion, cue], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className={styles.companion} aria-hidden="true">
      <div className={styles.slot}>
        <div className={styles.exit} data-exit>
          <div className={styles.drop} data-drop>
            <div className={styles.float} data-float>
              <div className={styles.tilt} data-tilt>
                <AppIcon />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
