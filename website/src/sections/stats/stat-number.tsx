"use client";

import { useRef } from "react";
import type { StatFigure } from "@/content/stats";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";

const grouping = new Intl.NumberFormat("en-US");

function format(figure: StatFigure, value: number) {
  if (figure.text) return figure.text;
  return `${figure.prefix ?? ""}${grouping.format(Math.round(value))}${figure.plus ? "+" : ""}${figure.suffix ?? ""}`;
}

export function StatNumber({ figure }: { figure: StatFigure }) {
  const ref = useRef<HTMLSpanElement>(null);
  const shownRef = useRef<number | null>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      const element = ref.current;
      if (!element) return;
      if (reducedMotion || figure.text) {
        element.textContent = format(figure, figure.value);
        shownRef.current = figure.value;
        return;
      }
      const counter = { value: shownRef.current ?? 0 };
      const render = () => {
        element.textContent = format(figure, counter.value);
        shownRef.current = counter.value;
      };
      render();
      gsap.to(counter, {
        value: figure.value,
        duration: shownRef.current === 0 ? 1.8 : 0.9,
        ease: "power3.out",
        onUpdate: render,
        scrollTrigger: shownRef.current === 0 ? { trigger: element, start: "top 88%", once: true } : undefined,
      });
    },
    { dependencies: [figure, reducedMotion], revertOnUpdate: true },
  );

  return (
    <>
      <span ref={ref} className="tabular" aria-hidden="true">
        {format(figure, figure.value)}
      </span>
      <span className="sr-only">{format(figure, figure.value)}</span>
    </>
  );
}
