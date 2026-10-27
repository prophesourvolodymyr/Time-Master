"use client";

import { useRef } from "react";
import { editPages } from "@/content/edit-pages";
import { gsap, useGSAP } from "@/lib/gsap";
import styles from "./film.module.css";

const editSeconds = 1.8;
const firstInterval = 0.2;
const acceleration = 0.8;
const shortestInterval = 0.05;
const flashPages = new Set([3, 7, 10]);

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
      const glow = root.querySelector("[data-edit-glow]");
      const flash = root.querySelector("[data-flash]");
      const times = pageTimes(pages.length);
      const timeline = gsap.timeline({
        onComplete: () => {
          gsap.set([root, ...pages], { autoAlpha: 0 });
          onDone();
        },
      });
      timeline.set(root, { autoAlpha: 1 }, 0);
      pages.forEach((page, index) => {
        const at = times[index];
        const gap = (times[index + 1] ?? editSeconds) - at;
        timeline.set(page, { autoAlpha: 1 }, at);
        if (index > 0) timeline.set(pages[index - 1], { autoAlpha: 0 }, at);
        timeline.fromTo(glow, { opacity: 0.95 }, { opacity: 0.35, duration: gap, ease: "power2.out", immediateRender: false }, at);
        if (flashPages.has(index)) timeline.fromTo(flash, { opacity: 0.6 }, { opacity: 0, duration: 0.08, ease: "none", immediateRender: false }, at);
      });
    },
    { scope: rootRef, dependencies: [run], revertOnUpdate: true },
  );

  return (
    <div ref={rootRef} className={styles.edit} aria-hidden="true">
      <div className={styles.editStack}>
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
