"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./stats.module.css";

const digits = "0123456789".split("");

export function RollingNumber({ text }: { text: string }) {
  const ref = useRef<HTMLSpanElement>(null);
  const [armed, setArmed] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        setArmed(true);
        observer.disconnect();
      },
      { threshold: 0.6 },
    );
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const shown = armed ? text : text.replace(/\d/g, "0");
  const characters = [...shown];

  return (
    <>
      <span ref={ref} className={styles.roll} aria-hidden="true">
        {characters.map((character, index) => {
          const fromRight = characters.length - index;
          if (!/\d/.test(character)) {
            return (
              <span key={`glyph-${fromRight}`} className={styles.glyph}>
                {character}
              </span>
            );
          }
          return (
            <span key={`digit-${fromRight}`} className={styles.digitWindow}>
              <span className={styles.digitColumn} style={{ transform: `translateY(-${Number(character)}em)`, transitionDelay: `${fromRight * 45}ms` }}>
                {digits.map((digit) => (
                  <span key={digit}>{digit}</span>
                ))}
              </span>
            </span>
          );
        })}
      </span>
      <span className="sr-only">{text}</span>
    </>
  );
}
