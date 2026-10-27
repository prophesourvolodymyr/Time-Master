"use client";

import dynamic from "next/dynamic";
import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { ArrowDownIcon } from "@phosphor-icons/react";
import { AppClip, DeviceFrame } from "@/components/media";
import { useChapter } from "@/components/providers/chapter";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { ActionButton } from "@/components/ui";
import { resolveClip } from "@/content/clip-stand-ins";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import { obsessions } from "./obsessions";
import type { PhoneScreen } from "./phone-wheel-canvas";
import { detent, type WheelState } from "./wheel";
import styles from "./choice.module.css";

const PhoneWheelCanvas = dynamic(() => import("./phone-wheel-canvas"), { ssr: false });

const lastIndex = obsessions.length - 1;
const stepScreens = 0.42;
const holdShare = 0.07;
const arrowSteps: Record<string, number> = { ArrowRight: 1, ArrowLeft: -1 };

const screens: readonly PhoneScreen[] = obsessions.map((item) => {
  const clip = resolveClip(item.clip);
  if (!clip) throw new Error(`No recording or stand-in for ${item.clip}`);
  return { src: clip.src, poster: clip.poster };
});

export function ObsessionWheel() {
  const stageRef = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const optionRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const triggerRef = useRef<ScrollTrigger | null>(null);
  const focusRef = useRef(0);
  const wheel = useMemo<WheelState>(() => ({ target: 0, current: 0 }), []);
  const [focus, setFocus] = useState(0);
  const [near, setNear] = useState(false);
  const [visible, setVisible] = useState(false);
  const { selectChapter } = useChapter();
  const { scrollTo } = useSmoothScroll();
  const reducedMotion = usePrefersReducedMotion();

  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) return;
    const nearObserver = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) setNear(true);
      },
      { rootMargin: "120% 0px" },
    );
    const visibleObserver = new IntersectionObserver(([entry]) => setVisible(entry.isIntersecting));
    nearObserver.observe(stage);
    visibleObserver.observe(stage);
    return () => {
      nearObserver.disconnect();
      visibleObserver.disconnect();
    };
  }, []);

  useGSAP(
    () => {
      if (reducedMotion) return;
      const stage = stageRef.current;
      const track = trackRef.current;
      if (!stage || !track) return;
      const items = optionRefs.current.filter((item): item is HTMLButtonElement => item !== null);

      triggerRef.current = ScrollTrigger.create({
        trigger: stage,
        start: "top top",
        end: () => `+=${window.innerHeight * (stepScreens * lastIndex + 0.5)}`,
        pin: true,
        onUpdate: (self) => {
          const travel = gsap.utils.clamp(0, 1, (self.progress - holdShare) / (1 - holdShare * 2));
          wheel.target = detent(travel * lastIndex);
        },
      });

      gsap.from("[data-wheel-enter]", {
        yPercent: 30,
        autoAlpha: 0,
        stagger: 0.08,
        duration: 1,
        ease: "expo.out",
        scrollTrigger: { trigger: stage, start: "top 75%", toggleActions: "play none none reverse" },
      });

      let centers: number[] = [];
      let drawn = Number.NaN;
      const measure = () => {
        centers = items.map((item) => item.offsetLeft + item.offsetWidth / 2);
        drawn = Number.NaN;
      };
      measure();
      const resizeObserver = new ResizeObserver(measure);
      resizeObserver.observe(track);

      const tick = (_time: number, deltaTime: number) => {
        const step = Math.min(deltaTime / 1000, 0.05);
        wheel.current += (wheel.target - wheel.current) * (1 - Math.exp(-step * 9));
        if (Math.abs(wheel.target - wheel.current) < 0.0005) wheel.current = wheel.target;
        if (wheel.current === drawn) return;
        drawn = wheel.current;
        const lower = Math.floor(drawn);
        const upper = Math.min(lastIndex, lower + 1);
        const center = centers[lower] + (centers[upper] - centers[lower]) * (drawn - lower);
        track.style.transform = `translate3d(${(-center).toFixed(1)}px, 0, 0)`;
        items.forEach((item, index) => {
          const offset = index - drawn;
          const distance = Math.min(Math.abs(offset), 3);
          item.style.opacity = (1 - distance * 0.27).toFixed(3);
          item.style.transform = `rotateY(${(offset * 16).toFixed(2)}deg) scale(${(1 - distance * 0.1).toFixed(3)})`;
        });
        const rounded = Math.round(drawn);
        if (rounded !== focusRef.current) {
          focusRef.current = rounded;
          setFocus(rounded);
        }
      };
      gsap.ticker.add(tick);

      return () => {
        gsap.ticker.remove(tick);
        resizeObserver.disconnect();
        triggerRef.current = null;
      };
    },
    { scope: stageRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  const spinTo = (index: number) => {
    const trigger = triggerRef.current;
    if (!trigger) {
      focusRef.current = index;
      setFocus(index);
      return;
    }
    const share = holdShare + (1 - holdShare * 2) * (index / lastIndex);
    scrollTo(trigger.start + (trigger.end - trigger.start) * share, { duration: 0.9 });
  };

  const dive = (index: number) => selectChapter(obsessions[index].chapter, { scroll: true });

  const choose = (index: number) => (index === focusRef.current ? dive(index) : spinTo(index));

  const moveFocus = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const step = arrowSteps[event.key];
    if (!step) return;
    event.preventDefault();
    const next = Math.min(lastIndex, Math.max(0, index + step));
    optionRefs.current[next]?.focus();
    spinTo(next);
  };

  const focused = obsessions[focus];

  return (
    <div ref={stageRef} className={styles.stage} data-static={reducedMotion || undefined}>
      <h2 id="choose-title" className="text-display text-center text-[clamp(30px,4.4vw,68px)]" data-wheel-enter>
        Pick your obsession.
      </h2>
      <div className={styles.strip} data-wheel-enter>
        <div ref={trackRef} className={styles.track}>
          {obsessions.map((item, index) => (
            <button
              key={item.label}
              ref={(element) => {
                optionRefs.current[index] = element;
              }}
              type="button"
              className={styles.option}
              data-focused={index === focus || undefined}
              aria-current={index === focus || undefined}
              onClick={() => choose(index)}
              onKeyDown={(event) => moveFocus(event, index)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <span className={styles.marker} aria-hidden="true" />
      </div>
      <div className={styles.phones} data-wheel-enter>
        {reducedMotion ? (
          <DeviceFrame className={styles.staticPhone}>
            <AppClip id={focused.clip} label={focused.label} />
          </DeviceFrame>
        ) : near ? (
          <PhoneWheelCanvas className={styles.canvas} screens={screens} wheel={wheel} active={visible} onPick={choose} />
        ) : null}
      </div>
      <div className={styles.cta} data-wheel-enter>
        <ActionButton prominent size={54} paddingX={22} icon={<ArrowDownIcon weight="bold" />} iconPosition="trailing" onClick={() => dive(focus)}>
          Explore {focused.label}
        </ActionButton>
        <p className={styles.hint}>{reducedMotion ? "Pick one, then explore it." : "Scroll to spin. Tap the phone to dive in."}</p>
      </div>
    </div>
  );
}
