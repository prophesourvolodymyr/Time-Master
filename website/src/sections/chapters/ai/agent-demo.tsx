"use client";

import { useRef, useState, type RefObject } from "react";
import clsx from "clsx";
import { FastForwardIcon } from "@phosphor-icons/react";
import { useImmersive } from "@/components/providers/immersive";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { ActionButton } from "@/components/ui";
import { gsap, Observer, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { AgentCard, emptyDraft, finishedDraft, type AgentDraft } from "./agent-card";
import { AgentInterception } from "./agent-interception";
import { agentDemo } from "./content";
import { accentChannels, talosOrange, type TalosPose } from "./talos-pose";
import { TalosPoster } from "./talos-stage";
import styles from "./ai-chapter.module.css";

type DemoPhase = "idle" | "playing" | "intercepted" | "done";

const demoSeconds = 7;
const interceptAt = 4.05;
const scrollKeys: Record<string, true> = {
  ArrowDown: true,
  ArrowUp: true,
  PageDown: true,
  PageUp: true,
  Home: true,
  End: true,
  " ": true,
};

export type AgentDemoProps = {
  pose: TalosPose;
  reducedMotion: boolean;
  sectionRef: RefObject<HTMLElement | null>;
};

export function AgentDemo({ pose, reducedMotion, sectionRef }: AgentDemoProps) {
  const pinRef = useRef<HTMLDivElement>(null);
  const stackRef = useRef<HTMLDivElement>(null);
  const cursorRef = useRef<HTMLDivElement>(null);
  const panelRef = useRef<HTMLDivElement>(null);
  const timelineRef = useRef<gsap.core.Timeline | null>(null);
  const skipRef = useRef<() => void>(() => undefined);
  const phaseRef = useRef<DemoPhase>("idle");
  const [phase, setPhase] = useState<DemoPhase>("idle");
  const [draft, setDraft] = useState<AgentDraft>(emptyDraft);
  const [countdown, setCountdown] = useState(3);
  const { scrollTo } = useSmoothScroll();
  const holding = !reducedMotion && (phase === "playing" || phase === "intercepted");
  useImmersive(holding);

  const shownPhase = reducedMotion ? "done" : phase;
  const shownDraft = reducedMotion ? finishedDraft : draft;

  useGSAP(
    (_, safe) => {
      const section = sectionRef.current;
      const panel = panelRef.current;
      const cursor = cursorRef.current;
      const stack = stackRef.current;
      if (reducedMotion || !section || !panel || !cursor || !stack || !safe) return;
      const sheet = panel.firstElementChild;
      let release = () => {};

      const enterPhase = (next: DemoPhase) => {
        phaseRef.current = next;
        setPhase(next);
      };
      const update = (patch: Partial<AgentDraft>) => setDraft((current) => ({ ...current, ...patch }));
      const tint = (hex: string, duration = 0.6) => gsap.to(pose, { ...accentChannels(hex), duration, ease: "power2.out" });
      const settle = safe(() => {
        release();
        timelineRef.current?.kill();
        timelineRef.current = null;
        setDraft(finishedDraft);
        gsap.set(cursor, { autoAlpha: 0 });
        gsap.set(panel, { autoAlpha: 1 });
        gsap.set(sheet, { yPercent: 0 });
        gsap.to(pose, { ...accentChannels(agentDemo.color), spin: 0, duration: 0.6, ease: "power2.out" });
        enterPhase("done");
      });
      const skip = safe(() => {
        if (phaseRef.current === "playing" || phaseRef.current === "intercepted") settle();
      });
      skipRef.current = skip;
      const complete = safe(() => {
        release();
        timelineRef.current = null;
        enterPhase("done");
        gsap.to(pose, { spin: 0, duration: 0.9, ease: "power2.inOut" });
        scrollTo("#stats", { duration: 1.6 });
      });
      const listen = () => {
        const observer = Observer.create({ target: window, type: "wheel,touch", tolerance: 12, onChangeY: skip });
        const onKey = (event: KeyboardEvent) => {
          const target = event.target instanceof Element ? event.target : null;
          if (scrollKeys[event.key] && !target?.closest("a, button, input, textarea, select")) skip();
        };
        window.addEventListener("keydown", onKey);
        release = () => {
          observer.kill();
          window.removeEventListener("keydown", onKey);
          release = () => {};
        };
      };

      const point = (target: string) => {
        const box = stack.getBoundingClientRect();
        const rect = stack.querySelector(`[data-demo-target="${target}"]`)?.getBoundingClientRect() ?? box;
        return { x: rect.left - box.left + rect.width * 0.5, y: rect.top - box.top + rect.height * 0.6 };
      };

      const play = safe(() => {
        if (phaseRef.current !== "idle") return;
        enterPhase("playing");
        listen();
        const start = point("create");
        const [firstHover, secondHover] = agentDemo.hoverColors;
        const timeline = gsap.timeline({ onComplete: complete });
        timelineRef.current = timeline;
        timeline
          .set(cursor, { x: start.x + 60, y: start.y + 40, autoAlpha: 0 }, 0)
          .to(cursor, { autoAlpha: 1, duration: 0.18 }, 0)
          .to(cursor, { ...point("username"), duration: 0.32, ease: "power2.inOut" }, 0)
          .to(cursor, { scale: 0.82, duration: 0.07, yoyo: true, repeat: 1 }, 0.33);
        Array.from(agentDemo.username).forEach((_, index) => {
          timeline.call(update, [{ typed: index + 1 }], 0.36 + (index + 1) * 0.068);
        });
        timeline
          .call(update, [{ availability: "checking" }], 1.36)
          .call(update, [{ availability: "available" }], 1.74)
          .to(cursor, { ...point(`color-${firstHover}`), duration: 0.24, ease: "power2.inOut" }, 1.8)
          .add(tint(firstHover, 0.2), 2.02)
          .to(cursor, { ...point(`color-${secondHover}`), duration: 0.16, ease: "power2.inOut" }, 2.1)
          .add(tint(secondHover, 0.2), 2.24)
          .to(cursor, { ...point(`color-${agentDemo.color}`), duration: 0.16, ease: "power2.inOut" }, 2.34)
          .to(cursor, { scale: 0.82, duration: 0.07, yoyo: true, repeat: 1 }, 2.5)
          .call(update, [{ color: agentDemo.color }], 2.52)
          .add(tint(agentDemo.color, 0.3), 2.52)
          .to(cursor, { ...point(`personality-${agentDemo.personality}`), duration: 0.3, ease: "power2.inOut" }, 2.7)
          .to(cursor, { scale: 0.82, duration: 0.07, yoyo: true, repeat: 1 }, 3)
          .call(update, [{ personality: agentDemo.personality }], 3.02)
          .to(cursor, { ...point("file"), duration: 0.28, ease: "power2.inOut" }, 3.16)
          .to(cursor, { scale: 0.82, duration: 0.07, yoyo: true, repeat: 1 }, 3.44)
          .call(update, [{ file: true }], 3.46)
          .to(cursor, { ...point("create"), duration: 0.3, ease: "power2.inOut" }, 3.6)
          .call(update, [{ pressing: true }], 3.92)
          .call(enterPhase, ["intercepted"], interceptAt)
          .to(cursor, { autoAlpha: 0, duration: 0.2 }, interceptAt)
          .set(panel, { autoAlpha: 1 }, interceptAt)
          .fromTo(sheet, { yPercent: 105 }, { yPercent: 0, duration: 0.8, ease: "expo.out" }, interceptAt)
          .to(pose, { spin: () => -pose.turn, duration: 0.9, ease: "power2.inOut" }, interceptAt + 0.1)
          .call(setCountdown, [2], interceptAt + 1)
          .call(setCountdown, [1], interceptAt + 2)
          .set({}, {}, demoSeconds);
      });

      gsap.set(panel, { autoAlpha: 0 });
      gsap.set(cursor, { autoAlpha: 0 });
      ScrollTrigger.create({
        trigger: section,
        start: "top 8px",
        end: "bottom top",
        onEnter: play,
        onEnterBack: () => {
          if (phaseRef.current === "idle") settle();
          else tint(agentDemo.color);
        },
        onLeaveBack: () => {
          skip();
          tint(talosOrange);
        },
      });
      return () => {
        release();
        phaseRef.current = "idle";
        skipRef.current = () => undefined;
        setPhase("idle");
        setDraft(emptyDraft);
        setCountdown(3);
      };
    },
    { scope: pinRef, dependencies: [reducedMotion, pose, scrollTo], revertOnUpdate: true },
  );

  const holdTimeline = (held: boolean) => {
    const timeline = timelineRef.current;
    if (!timeline || phaseRef.current !== "intercepted") return;
    if (held) timeline.pause();
    else timeline.resume();
  };

  return (
    <section ref={sectionRef} className={clsx(styles.demo, reducedMotion && styles.demoStill)}>
      <div ref={pinRef} className={styles.demoPin}>
        <div className={styles.demoColumn}>
          <h3 className={styles.demoTitle}>Now build yours.</h3>
          <p className={styles.demoLine}>{reducedMotion ? "Here's one we made earlier." : "Seven seconds. Hands off the trackpad."}</p>
          <p className="sr-only">
            A short demo creates an agent called @{agentDemo.username}, picks blue, sets a strict personality and adds a goals file.
          </p>
          <div ref={stackRef} className={clsx(styles.demoStack, shownPhase !== "idle" && shownPhase !== "playing" && styles.demoStackIntercepted)}>
            <AgentCard draft={shownDraft} />
            <div ref={cursorRef} className={styles.cursor} aria-hidden="true">
              <svg viewBox="0 0 24 24" width="26" height="26">
                <path d="M5 3l14 8.2-6.1 1.5 3.6 6.6-2.7 1.4-3.6-6.6L5 18.6z" fill="#fff" stroke="#000" strokeWidth="1.4" strokeLinejoin="round" />
              </svg>
            </div>
            <AgentInterception
              panelRef={panelRef}
              countdown={shownPhase === "intercepted" ? countdown : null}
              onHoldChange={holdTimeline}
            />
          </div>
          <p className="sr-only" aria-live="polite">
            {shownPhase === "intercepted" ? `Wait. @${agentDemo.username} is free. Only the app can claim it.` : ""}
          </p>
        </div>
        {reducedMotion ? <TalosPoster className={styles.demoPoster} /> : null}
        {holding ? (
          <ActionButton
            size={40}
            font="text"
            paddingX={14}
            icon={<FastForwardIcon weight="fill" />}
            iconPosition="trailing"
            className={styles.skip}
            onClick={() => skipRef.current()}
          >
            Skip demo
          </ActionButton>
        ) : null}
      </div>
    </section>
  );
}
