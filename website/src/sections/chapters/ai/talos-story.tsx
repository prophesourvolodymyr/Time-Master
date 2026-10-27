"use client";

import { useEffect, useRef, useState, type RefObject } from "react";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { gsap, Observer, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { useMediaQuery, usePrefersReducedMotion } from "@/lib/motion";
import { appClips } from "@/content/app-clips";
import { FeatureBeat } from "../shared/feature-beat";
import { AgentDemo } from "./agent-demo";
import { talosBeats } from "./content";
import { StrobeIntro } from "./strobe-intro";
import { TalosLine } from "./talos-line";
import { buildPathTimeline, snapTarget, stationPoses, stepTarget, timeAtScroll, type TalosStation } from "./talos-path";
import { createTalosPose } from "./talos-pose";
import { TalosStage } from "./talos-stage";
import styles from "./ai-chapter.module.css";

const beatLayouts = talosBeats.map((beat) => ({
  beat,
  recorded: appClips[beat.clip] !== undefined,
}));

const stations: readonly TalosStation[] = [
  "intro",
  "intro",
  ...beatLayouts.map(({ beat, recorded }): TalosStation => {
    if (recorded) return beat.side === "left" ? "device-left" : "device-right";
    return beat.side === "left" ? "solo-left" : "solo-right";
  }),
  "demo",
];

function useViewportPresence(target: RefObject<HTMLElement | null>, enabled: boolean) {
  const [near, setNear] = useState(false);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const element = target.current;
    if (!enabled || !element) return;
    const nearObserver = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) setNear(true);
    }, { rootMargin: "150% 0px" });
    const visibleObserver = new IntersectionObserver(([entry]) => setVisible(entry.isIntersecting));
    nearObserver.observe(element);
    visibleObserver.observe(element);
    return () => {
      nearObserver.disconnect();
      visibleObserver.disconnect();
    };
  }, [target, enabled]);

  return { near, visible };
}

export function TalosStory() {
  const reducedMotion = usePrefersReducedMotion();
  const wide = useMediaQuery("(min-width: 768px)", true);
  const [pose] = useState(createTalosPose);
  const rootRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const introRef = useRef<HTMLElement>(null);
  const demoRef = useRef<HTMLElement>(null);
  const beatRefs = useRef<(HTMLDivElement | null)[]>([]);
  const { scrollTo } = useSmoothScroll();
  const { near, visible } = useViewportPresence(rootRef, !reducedMotion);
  const [modelReady, setModelReady] = useState(false);

  useGSAP(
    () => {
      const stage = stageRef.current;
      const intro = introRef.current;
      const demo = demoRef.current;
      const beats = beatRefs.current.filter((beat): beat is HTMLDivElement => beat !== null);
      if (reducedMotion || !stage || !intro || !demo || beats.length !== talosBeats.length) return;

      const path = buildPathTimeline(stage, pose, stationPoses(stations, wide));
      let marks: number[] = [];
      let rests: number[] = [];
      let direction = 1;
      const measure = () => {
        const viewport = window.innerHeight;
        const top = (element: HTMLElement) => element.getBoundingClientRect().top + window.scrollY;
        const introTop = top(intro);
        const beatRests = beats.map((beat) => top(beat) + beat.offsetHeight / 2 - viewport / 2);
        const demoTop = top(demo);
        marks = [introTop, introTop + viewport * 0.25, ...beatRests, demoTop];
        rests = [introTop, ...beatRests, demoTop];
      };

      measure();
      path.time(timeAtScroll(window.scrollY, marks));
      ScrollTrigger.create({
        trigger: rootRef.current,
        start: "top bottom",
        end: "bottom top",
        onRefresh: measure,
        onUpdate: (self) => {
          direction = self.direction;
          gsap.to(path, { time: timeAtScroll(self.scroll(), marks), duration: 0.85, ease: "power3.out", overwrite: true });
        },
      });

      const settle = () => {
        const target = snapTarget(window.scrollY, rests, direction, window.innerHeight);
        if (target === undefined) return;
        const distance = Math.abs(target - window.scrollY) / window.innerHeight;
        scrollTo(target, { duration: Math.min(0.95, 0.42 + distance * 0.38), lock: true });
      };
      let ready = true;
      const step = (forward: boolean) => {
        if (!ready) return;
        const target = stepTarget(window.scrollY, rests, forward, window.innerHeight * 0.3);
        if (target === undefined) return;
        ready = false;
        scrollTo(target, { duration: 0.85, lock: true });
      };
      const wheel = Observer.create({
        target: window,
        type: "wheel",
        tolerance: 4,
        onStopDelay: 0.2,
        onDown: () => step(true),
        onUp: () => step(false),
        onStop: () => {
          ready = true;
        },
      });
      ScrollTrigger.addEventListener("scrollEnd", settle);
      return () => {
        wheel.kill();
        ScrollTrigger.removeEventListener("scrollEnd", settle);
      };
    },
    { scope: rootRef, dependencies: [reducedMotion, wide, pose, scrollTo], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className={styles.story}>
      {reducedMotion ? null : (
        <TalosStage pose={pose} stageRef={stageRef} near={near} active={visible} onModelReady={() => setModelReady(true)} />
      )}
      <StrobeIntro pose={pose} reducedMotion={reducedMotion} modelReady={modelReady} sectionRef={introRef} />
      <div className={styles.beats}>
        {beatLayouts.map(({ beat, recorded }, index) => (
          <div
            key={beat.clip}
            ref={(element) => {
              beatRefs.current[index] = element;
            }}
          >
            {recorded ? (
              <FeatureBeat clip={beat.clip} title={beat.title} lines={[beat.line]} side={beat.side} />
            ) : (
              <TalosLine beat={beat} still={reducedMotion} />
            )}
          </div>
        ))}
      </div>
      <AgentDemo pose={pose} reducedMotion={reducedMotion} sectionRef={demoRef} />
    </div>
  );
}
