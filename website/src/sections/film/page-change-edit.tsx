"use client";

import { useRef } from "react";
import { editPages } from "@/content/edit-pages";
import { gsap, useGSAP } from "@/lib/gsap";
import styles from "./film.module.css";

export const editSeconds = 3;

const firstInterval = 0.34;
const acceleration = 0.84;
const shortestInterval = 0.07;
const swipeLongerThan = 0.13;
const flashPages = new Set([4, 8, 11]);

function pageTimes(count: number) {
  const times: number[] = [];
  let time = 0;
  let interval = firstInterval;
  for (let index = 0; index < count; index += 1) {
    times.push(time);
    time += interval;
    interval = Math.max(shortestInterval, interval * acceleration);
  }
  return times;
}

const shake = (index: number, salt: number) => Math.sin(index * 2.399 + salt * 1.618);

export type PageChangeEditProps = {
  run: number;
  prepared: boolean;
  onDone: () => void;
};

export function PageChangeEdit({ run, prepared, onDone }: PageChangeEditProps) {
  const rootRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (run === 0) return;
      const root = rootRef.current;
      if (!root) return;
      const pages = gsap.utils.toArray<HTMLElement>("[data-edit-page]", root);
      const stack = root.querySelector("[data-edit-stack]");
      const glow = root.querySelector("[data-edit-glow]");
      const flash = root.querySelector("[data-flash]");
      const times = pageTimes(pages.length);
      const timeline = gsap.timeline({
        onComplete: () => {
          gsap.set([root, ...pages], { autoAlpha: 0 });
          onDone();
        },
      });
      timeline.fromTo(root, { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.06, ease: "none" }, 0);
      timeline.fromTo(stack, { scale: 1 }, { scale: 1.24, duration: editSeconds, ease: "power2.in" }, 0);
      pages.forEach((page, index) => {
        const at = times[index];
        const gap = (times[index + 1] ?? editSeconds) - at;
        const previous = pages[index - 1];
        if (gap > swipeLongerThan) {
          const side = index % 2 === 0 ? 1 : -1;
          const swipe = Math.min(0.2, gap * 0.6);
          timeline.fromTo(
            page,
            { autoAlpha: 1, xPercent: 100 * side, rotate: 2.5 * side, scale: 1.06, filter: "blur(14px)" },
            { xPercent: 0, rotate: 0, scale: 1, filter: "blur(0px)", duration: swipe, ease: "expo.out", immediateRender: false },
            at,
          );
          if (previous) {
            timeline.to(previous, { xPercent: -45 * side, filter: "blur(10px)", duration: swipe * 0.8, ease: "power2.in" }, at);
            timeline.set(previous, { autoAlpha: 0 }, at + swipe * 0.8);
          }
        } else {
          timeline.fromTo(
            page,
            { autoAlpha: 1, xPercent: 0, scale: 1.14, x: shake(index, 1) * 18, y: shake(index, 2) * 12, rotate: shake(index, 3) * 0.8, filter: "blur(0px)" },
            { scale: 1, x: 0, y: 0, rotate: 0, duration: Math.max(0.06, gap * 0.9), ease: "power3.out", immediateRender: false },
            at,
          );
          if (previous) timeline.set(previous, { autoAlpha: 0 }, at);
        }
        timeline.fromTo(glow, { opacity: 0.95, scale: 0.85 }, { opacity: 0.3, scale: 1.12, duration: gap, ease: "power2.out", immediateRender: false }, at);
        if (flashPages.has(index)) timeline.fromTo(flash, { opacity: 0.7 }, { opacity: 0, duration: 0.12, ease: "none", immediateRender: false }, at);
      });
    },
    { scope: rootRef, dependencies: [run], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className={styles.edit} aria-hidden="true">
      <div className={styles.editStack} data-edit-stack>
        {prepared
          ? editPages.map((page) => (
              <picture key={page.desktop} className={styles.editPage} data-edit-page>
                <source media="(max-aspect-ratio: 1/1)" srcSet={page.mobile} />
                <img src={page.desktop} alt="" decoding="async" />
              </picture>
            ))
          : null}
        <span className={styles.editGlow} data-edit-glow />
      </div>
      <span className={styles.editGrain} />
      <span className={styles.editVignette} />
      <span className={styles.flash} data-flash />
    </div>
  );
}
