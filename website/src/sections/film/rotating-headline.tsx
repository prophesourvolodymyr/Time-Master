"use client";

import { useEffect, useRef, useState } from "react";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import styles from "./film.module.css";

const titles = [
  { accent: "Everything", rest: "App" },
  { accent: "Social", rest: "Media" },
  { accent: "AI", rest: "Coach" },
] as const;

const holdSeconds = 3.6;

function Slot({ words, delay = 0 }: { words: readonly string[]; delay?: number }) {
  return (
    <span className={styles.slot} data-slot data-delay={delay}>
      {words.map((word) => (
        <span key={word} className={styles.slotWord} data-word>
          {[...word].map((letter, index) => (
            <span key={index} className={styles.slotLetter}>
              {letter}
            </span>
          ))}
        </span>
      ))}
    </span>
  );
}

export function RotatingHeadline() {
  const rootRef = useRef<HTMLSpanElement>(null);
  const shownRef = useRef(0);
  const [index, setIndex] = useState(0);
  const reducedMotion = usePrefersReducedMotion();

  useEffect(() => {
    if (reducedMotion) return;
    const timer = window.setInterval(() => {
      if (!document.hidden) setIndex((current) => (current + 1) % titles.length);
    }, holdSeconds * 1000);
    return () => window.clearInterval(timer);
  }, [reducedMotion]);

  useGSAP(
    () => {
      const root = rootRef.current;
      const from = shownRef.current;
      if (!root || from === index) return;
      shownRef.current = index;
      for (const slot of root.querySelectorAll<HTMLElement>("[data-slot]")) {
        const words = slot.querySelectorAll<HTMLElement>("[data-word]");
        const outgoing = words[from];
        const incoming = words[index];
        const fontSize = parseFloat(getComputedStyle(slot).fontSize);
        const timeline = gsap.timeline({ delay: Number(slot.dataset.delay) });
        timeline.set(slot, { width: `${outgoing.offsetWidth / fontSize}em` }, 0);
        timeline.to(outgoing.children, { yPercent: -70, autoAlpha: 0, filter: "blur(10px)", duration: 0.34, stagger: 0.024, ease: "power2.in" }, 0);
        timeline.to(slot, { width: `${incoming.offsetWidth / fontSize}em`, duration: 0.6, ease: "power3.inOut" }, 0.12);
        timeline.fromTo(
          incoming.children,
          { yPercent: 70, autoAlpha: 0, filter: "blur(10px)" },
          { yPercent: 0, autoAlpha: 1, filter: "blur(0px)", duration: 0.52, stagger: 0.03, ease: "power3.out" },
          0.26,
        );
      }
    },
    { scope: rootRef, dependencies: [index] },
  );

  return (
    <span ref={rootRef}>
      <span className={styles.headlineLine}>A Fitness</span>
      <em className={styles.headlineLine}>
        <Slot words={titles.map((title) => title.accent)} />
      </em>
      <span className={styles.headlineLine}>
        <Slot words={titles.map((title) => title.rest)} delay={0.07} /> You
      </span>
      <span className={styles.headlineLine}>Dreamed Of</span>
    </span>
  );
}
