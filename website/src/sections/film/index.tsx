"use client";

import { useRef, useState } from "react";
import { appClips, type AppClipId } from "@/content/app-clips";
import { filmFeatures } from "@/content/features";
import film from "@/content/film.json";
import { useImmersive } from "@/components/providers/immersive";
import { useSmoothScroll } from "@/components/providers/smooth-scroll";
import { gsap, useGSAP } from "@/lib/gsap";
import { useMediaQuery, usePrefersReducedMotion } from "@/lib/motion";
import { ActionRail } from "./action-rail";
import { FrameSequence } from "./frame-sequence";
import { HeroCopy } from "./hero-copy";
import { rectToQuadTransform, type Point } from "./homography";
import { PageChangeEdit } from "./page-change-edit";
import { ScreenClip } from "./screen-clip";
import styles from "./film.module.css";

type Variant = "desktop" | "mobile";

const plane = { width: 402, height: 874 };
const lastFrame = film.frameCount - 1;
const idleLastFrame = 54;
const pushEnd = 0.3;
const wordsEnd = 0.9;
const editStart = 0.985;
const screenBleed = 1.012;
const pushEase = gsap.parseEase("power1.inOut");

const featureStarts = (() => {
  const weights = filmFeatures.map((_, index) => 0.84 ** index);
  const total = weights.reduce((sum, weight) => sum + weight, 0);
  let covered = 0;
  return weights.map((weight) => {
    const start = pushEnd + ((wordsEnd - pushEnd) * covered) / total;
    covered += weight;
    return start;
  });
})();

const screenClipIds = [...new Set<AppClipId>(["home", ...filmFeatures.map((feature) => feature.clip)])].filter((id) => appClips[id]);

function featureAt(progress: number) {
  if (progress < pushEnd) return -1;
  let index = 0;
  while (index + 1 < featureStarts.length && progress >= featureStarts[index + 1]) index += 1;
  return index;
}

function screenQuad(values: readonly number[], scale: number, dx: number, dy: number): Point[] {
  const points: Point[] = [0, 2, 4, 6].map((i) => [values[i] * scale + dx, values[i + 1] * scale + dy]);
  const cx = points.reduce((sum, [x]) => sum + x, 0) / 4;
  const cy = points.reduce((sum, [, y]) => sum + y, 0) / 4;
  return points.map(([x, y]) => [cx + (x - cx) * screenBleed, cy + (y - cy) * screenBleed]);
}

function framePath(variant: Variant, index: number) {
  return `/media/film/${variant}/${String(index).padStart(4, "0")}.webp`;
}

export function FilmSection() {
  const reducedMotion = usePrefersReducedMotion();
  const mobile = useMediaQuery("(max-aspect-ratio: 1/1)");
  const variant: Variant = mobile ? "mobile" : "desktop";
  const stageRef = useRef<HTMLDivElement>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const screenRef = useRef<HTMLDivElement>(null);
  const planeRef = useRef<HTMLDivElement>(null);
  const heroRef = useRef<HTMLDivElement>(null);
  const posterRef = useRef<HTMLPictureElement>(null);
  const progressRef = useRef(0);
  const editPlayedRef = useRef(false);
  const [feature, setFeature] = useState(-1);
  const [immersive, setImmersive] = useState(false);
  const [editRun, setEditRun] = useState(0);
  const { scrollTo, stop, start, isGliding } = useSmoothScroll();
  useImmersive(immersive);

  useGSAP(
    () => {
      const canvas = canvasRef.current;
      const context = canvas?.getContext("2d");
      if (!canvas || !context) return;
      const meta = film[variant];
      const sequence = new FrameSequence(Array.from({ length: film.frameCount }, (_, index) => framePath(variant, index)));
      const loading = new AbortController();
      const view = { width: 0, height: 0, ratio: 1, frame: 0, drawn: -1 };

      const draw = (force = false) => {
        const index = sequence.nearest(Math.round(view.frame));
        if (index < 0 || (index === view.drawn && !force)) return;
        const image = sequence.frame(index);
        if (!image) return;
        const scale = Math.max(view.width / meta.width, view.height / meta.height);
        const dx = (view.width - meta.width * scale) / 2;
        const dy = (view.height - meta.height * scale) / 2;
        context.setTransform(view.ratio, 0, 0, view.ratio, 0, 0);
        context.clearRect(0, 0, view.width, view.height);
        context.drawImage(image, dx, dy, meta.width * scale, meta.height * scale);
        const transform = rectToQuadTransform(plane.width, plane.height, screenQuad(meta.quads[index], scale, dx, dy));
        if (screenRef.current) screenRef.current.style.transform = transform;
        if (planeRef.current) planeRef.current.style.transform = transform;
        posterRef.current?.setAttribute("hidden", "");
        view.drawn = index;
      };

      const resize = () => {
        view.ratio = Math.min(window.devicePixelRatio || 1, 2);
        view.width = canvas.clientWidth;
        view.height = canvas.clientHeight;
        canvas.width = Math.round(view.width * view.ratio);
        canvas.height = Math.round(view.height * view.ratio);
        draw(true);
      };
      const observer = new ResizeObserver(resize);
      observer.observe(canvas);
      sequence.load(loading.signal, () => draw(true));

      if (reducedMotion) {
        return () => {
          observer.disconnect();
          loading.abort();
        };
      }

      const idle = (seconds: number) => {
        if (progressRef.current > 0) return;
        const cycle = ((idleLastFrame / film.fps) * 2) / 0.6;
        const phase = (seconds % cycle) / cycle;
        view.frame = (phase < 0.5 ? phase * 2 : 2 - phase * 2) * idleLastFrame;
        draw();
      };
      gsap.ticker.add(idle);

      const hero = heroRef.current?.querySelectorAll("[data-hero-part]") ?? [];
      const word = planeRef.current?.querySelector("[data-word]") ?? null;
      const rail = planeRef.current?.querySelector("[data-rail]") ?? null;
      const timeline = gsap.timeline({
        defaults: { ease: "none" },
        scrollTrigger: {
          trigger: stageRef.current,
          start: "top top",
          end: () => `+=${window.innerHeight * (mobile ? 4.2 : 5.2)}`,
          pin: true,
          scrub: true,
          onUpdate: (self) => {
            const progress = self.progress;
            progressRef.current = progress;
            if (progress > 0) view.frame = progress < pushEnd ? idleLastFrame + (lastFrame - idleLastFrame) * pushEase(progress / pushEnd) : lastFrame;
            draw();
            setFeature(featureAt(progress));
            setImmersive(progress > 0.02 && progress < 1);
            if (progress < 0.9) editPlayedRef.current = false;
            if (progress >= editStart && self.direction > 0 && !editPlayedRef.current && !isGliding()) {
              editPlayedRef.current = true;
              stop();
              setEditRun((run) => run + 1);
            }
          },
        },
      });
      timeline.to(hero, { xPercent: 22, autoAlpha: 0, stagger: 0.025, ease: "power2.in", duration: 0.1 }, 0.015);
      timeline.fromTo(sceneRef.current, { scale: 1, y: 0 }, { scale: 0.92, y: "6vh", ease: "power2.inOut", duration: 0.1 }, pushEnd - 0.1);
      timeline.fromTo(word, { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.02 }, pushEnd);
      timeline.fromTo(rail, { autoAlpha: 0, x: 40 }, { autoAlpha: 1, x: 0, duration: 0.04 }, pushEnd + 0.02);
      timeline.set({}, {}, 1);

      return () => {
        gsap.ticker.remove(idle);
        observer.disconnect();
        loading.abort();
      };
    },
    { scope: stageRef, dependencies: [variant, reducedMotion, mobile], revertOnUpdate: true },
  );

  const finishEdit = () => {
    start();
    scrollTo("#choose", { immediate: true });
  };

  const activeClip: AppClipId = feature < 0 ? "home" : filmFeatures[feature].clip;
  const current = filmFeatures[Math.max(0, feature)];

  return (
    <section id="top" aria-label="Tmax in the hand of a marble statue">
      <div ref={stageRef} className={styles.stage}>
        <div ref={sceneRef} className={styles.scene}>
          <picture ref={posterRef} className={styles.poster}>
            <source media="(max-aspect-ratio: 1/1)" srcSet={framePath("mobile", 0)} />
            <img src={framePath("desktop", 0)} alt="" fetchPriority="high" decoding="async" />
          </picture>
          <div ref={screenRef} className={styles.screen}>
            {screenClipIds.map((id) => (
              <ScreenClip key={id} id={id} active={id === activeClip} playing={!reducedMotion} />
            ))}
          </div>
          <canvas ref={canvasRef} className={styles.canvas} aria-hidden="true" />
          <div ref={planeRef} className={styles.plane}>
            <p className={styles.word} data-word aria-hidden="true">
              <span key={feature} className="inline-block animate-[word-in_260ms_var(--ease-out-expo)]">
                {current.word}
                {feature <= 2 ? (
                  <span className={styles.dots}>
                    <span>.</span>
                    <span>.</span>
                    <span>.</span>
                  </span>
                ) : null}
              </span>
            </p>
            <ActionRail step={Math.max(0, feature)} />
          </div>
        </div>
        <HeroCopy ref={heroRef} onInstall={() => scrollTo("#choose", { duration: 1.8, lock: true })} />
        {reducedMotion ? null : <PageChangeEdit run={editRun} scene={sceneRef} onDone={finishEdit} />}
      </div>
      <h2 className="sr-only">Everything inside Tmax</h2>
      <ul className={reducedMotion ? "mx-auto grid max-w-[1400px] grid-cols-2 gap-x-6 gap-y-3 px-5 py-20 font-display text-[28px] font-black md:grid-cols-4 md:px-8" : "sr-only"}>
        {filmFeatures.map((item) => (
          <li key={item.word}>{item.word}</li>
        ))}
      </ul>
    </section>
  );
}
