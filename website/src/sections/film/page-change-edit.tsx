"use client";

import { useRef, type RefObject } from "react";
import { editWords } from "@/content/features";
import { gsap, useGSAP } from "@/lib/gsap";
import styles from "./film.module.css";

export const editSeconds = 3;

const flashTimes = [0.62, 1.38, 1.96, 2.42, 2.78];

function highlightSchedule() {
  const times: number[] = [];
  let time = 0.12;
  let interval = 0.17;
  while (time < editSeconds - 0.42) {
    times.push(time);
    time += interval;
    interval = Math.max(0.045, interval * 0.88);
  }
  return times;
}

export type PageChangeEditProps = {
  run: number;
  scene: RefObject<HTMLDivElement | null>;
  onDone: () => void;
};

export function PageChangeEdit({ run, scene, onDone }: PageChangeEditProps) {
  const rootRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (run === 0) return;
      const root = rootRef.current;
      if (!root) return;
      const words = gsap.utils.toArray<HTMLElement>("[data-edit-word]", root);
      const block = root.querySelector("[data-edit-block]");
      const flash = root.querySelector("[data-flash]");
      const light = (index: number) => words.forEach((word, i) => word.toggleAttribute("data-on", i === index));
      const pool = words.length - 1;
      let previous = -1;
      const timeline = gsap.timeline({
        onComplete: () => {
          gsap.set(root, { autoAlpha: 0 });
          light(-1);
          onDone();
        },
      });
      timeline.set(root, { autoAlpha: 1 }, 0);
      timeline.fromTo(block, { scale: 0.9, rotate: -3 }, { scale: 2.1, rotate: 1.5, duration: editSeconds, ease: "power2.in" }, 0);
      timeline.to(scene.current, { scale: 2.6, duration: editSeconds, ease: "power3.in" }, 0);
      for (const time of highlightSchedule()) {
        timeline.call(() => {
          let next = previous;
          while (next === previous) next = Math.floor(Math.random() * pool);
          previous = next;
          light(next);
        }, [], time);
      }
      timeline.call(() => light(pool), [], editSeconds - 0.4);
      for (const time of flashTimes) timeline.fromTo(flash, { opacity: 0.85 }, { opacity: 0, duration: 0.14, ease: "none" }, time);
    },
    { scope: rootRef, dependencies: [run] },
  );

  return (
    <div ref={rootRef} className={styles.edit} aria-hidden="true">
      <p className={styles.editWords} data-edit-block>
        {editWords.map((word) => (
          <span key={word} className={styles.editWord} data-edit-word>
            {word}
          </span>
        ))}
      </p>
      <span className={styles.flash} data-flash />
    </div>
  );
}
