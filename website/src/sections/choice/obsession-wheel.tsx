"use client";

import dynamic from "next/dynamic";
import { useEffect, useLayoutEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { ArrowDownIcon, DownloadSimpleIcon } from "@phosphor-icons/react";
import { AppClip, DeviceFrame } from "@/components/media";
import { useInstall } from "@/components/install/install-sheet";
import { useChapter } from "@/components/providers/chapter";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { ActionButton } from "@/components/ui";
import type { AppClipId } from "@/content/app-clips";
import { resolveClip } from "@/content/clip-stand-ins";
import { desktopRecording } from "@/content/desktop-recording";
import { gsap, ScrollTrigger, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import type { ScreenSource } from "./devices/device-parts";
import { familyIndex, obsessions } from "./obsessions";
import type { FamilySources } from "./phone-wheel-canvas";
import { detent, type WheelState } from "./wheel";
import styles from "./choice.module.css";

const PhoneWheelCanvas = dynamic(() => import("./phone-wheel-canvas"), { ssr: false });

const lastIndex = obsessions.length - 1;
const stepScreens = 0.42;
const holdShare = 0.07;
const arrowSteps: Record<string, number> = { ArrowRight: 1, ArrowLeft: -1 };

function sourceFor(id: AppClipId): ScreenSource {
  const clip = resolveClip(id);
  if (!clip) throw new Error(`No recording or stand-in for ${id}`);
  return { src: clip.src, poster: clip.poster, aspect: clip.width / clip.height };
}

const screens: readonly ScreenSource[] = obsessions.map((item) => sourceFor(item.clip));

const desktop: ScreenSource | null = desktopRecording
  ? { src: desktopRecording.src, poster: desktopRecording.poster, aspect: desktopRecording.width / desktopRecording.height }
  : null;

const family: FamilySources = {
  laptop: desktop ?? sourceFor("home"),
  monitor: desktop ?? sourceFor("builder"),
  android: sourceFor("routes"),
  watch: sourceFor("timer"),
};

type StripLayout = {
  lefts: number[];
  widths: number[];
  overflow: number;
  inner: number;
};

function measureStrip(base: HTMLElement, track: HTMLElement, options: HTMLElement[]): StripLayout {
  const padding = parseFloat(getComputedStyle(base).paddingLeft) * 2;
  const inner = base.clientWidth - padding;
  const overflow = Math.max(0, track.offsetWidth - inner);
  base.toggleAttribute("data-overflow", overflow > 0);
  return { lefts: options.map((option) => option.offsetLeft), widths: options.map((option) => option.offsetWidth), overflow, inner };
}

function placeStrip(layout: StripLayout, position: number, track: HTMLElement, thumb: HTMLElement, follow: boolean) {
  const lower = Math.floor(position);
  const upper = Math.min(lastIndex, lower + 1);
  const fraction = position - lower;
  const x = layout.lefts[lower] + (layout.lefts[upper] - layout.lefts[lower]) * fraction;
  const width = layout.widths[lower] + (layout.widths[upper] - layout.widths[lower]) * fraction;
  thumb.style.transform = `translate3d(${x.toFixed(1)}px, 0, 0)`;
  thumb.style.width = `${width.toFixed(1)}px`;
  const shift = follow && layout.overflow > 0 ? gsap.utils.clamp(-layout.overflow, 0, layout.inner / 2 - (x + width / 2)) : 0;
  track.style.transform = `translate3d(${shift.toFixed(1)}px, 0, 0)`;
}

export function ObsessionWheel() {
  const stageRef = useRef<HTMLDivElement>(null);
  const baseRef = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const thumbRef = useRef<HTMLSpanElement>(null);
  const optionRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const triggerRef = useRef<ScrollTrigger | null>(null);
  const focusRef = useRef(0);
  const wheel = useMemo<WheelState>(() => ({ target: 0, current: 0 }), []);
  const [focus, setFocus] = useState(0);
  const [near, setNear] = useState(false);
  const [visible, setVisible] = useState(false);
  const { selectChapter } = useChapter();
  const { openInstall } = useInstall();
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

  useLayoutEffect(() => {
    if (!reducedMotion) return;
    const base = baseRef.current;
    const track = trackRef.current;
    const thumb = thumbRef.current;
    const options = optionRefs.current.filter((option): option is HTMLButtonElement => option !== null);
    if (!base || !track || !thumb) return;
    placeStrip(measureStrip(base, track, options), focus, track, thumb, false);
  }, [reducedMotion, focus]);

  useGSAP(
    () => {
      if (reducedMotion) return;
      const stage = stageRef.current;
      const base = baseRef.current;
      const track = trackRef.current;
      const thumb = thumbRef.current;
      if (!stage || !base || !track || !thumb) return;
      const options = optionRefs.current.filter((option): option is HTMLButtonElement => option !== null);

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

      let layout = measureStrip(base, track, options);
      let drawn = Number.NaN;
      const resizeObserver = new ResizeObserver(() => {
        layout = measureStrip(base, track, options);
        drawn = Number.NaN;
      });
      resizeObserver.observe(base);
      resizeObserver.observe(track);

      const tick = (_time: number, deltaTime: number) => {
        const step = Math.min(deltaTime / 1000, 0.05);
        wheel.current += (wheel.target - wheel.current) * (1 - Math.exp(-step * 9));
        if (Math.abs(wheel.target - wheel.current) < 0.0005) wheel.current = wheel.target;
        if (wheel.current === drawn) return;
        drawn = wheel.current;
        placeStrip(layout, drawn, track, thumb, true);
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

  const dive = (index: number) => {
    const chapter = obsessions[index].chapter;
    if (chapter) selectChapter(chapter, { scroll: true });
    else openInstall();
  };

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
        <div ref={baseRef} className={styles.stripBase}>
          <div ref={trackRef} className={styles.stripTrack}>
            <span ref={thumbRef} className={styles.stripThumb} aria-hidden="true" />
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
                <item.icon weight="bold" aria-hidden="true" />
                {item.label}
              </button>
            ))}
          </div>
        </div>
      </div>
      <div className={styles.phones} data-wheel-enter>
        {reducedMotion ? (
          <DeviceFrame className={styles.staticPhone}>
            <AppClip id={focused.clip} label={focused.label} />
          </DeviceFrame>
        ) : near ? (
          <PhoneWheelCanvas className={styles.canvas} screens={screens} family={family} familyIndex={familyIndex} wheel={wheel} active={visible} onPick={choose} />
        ) : null}
      </div>
      <div className={styles.cta} data-wheel-enter>
        <ActionButton
          prominent
          size={54}
          paddingX={22}
          icon={focused.chapter ? <ArrowDownIcon weight="bold" /> : <DownloadSimpleIcon weight="bold" />}
          iconPosition="trailing"
          onClick={() => dive(focus)}
        >
          {focused.chapter ? `Explore ${focused.label}` : "Get Tmax everywhere"}
        </ActionButton>
        <p className={styles.hint}>{reducedMotion ? "Pick one, then explore it." : "Scroll to switch. Tap the phone to dive in."}</p>
      </div>
    </div>
  );
}
