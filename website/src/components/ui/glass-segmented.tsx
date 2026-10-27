"use client";

import { useLayoutEffect, useRef, type KeyboardEvent } from "react";
import clsx from "clsx";
import type { Icon } from "@phosphor-icons/react";
import styles from "./glass-strip.module.css";

export type GlassSegmentedOption<T extends string> = {
  value: T;
  label: string;
  icon: Icon;
};

export type GlassSegmentedProps<T extends string> = {
  options: readonly GlassSegmentedOption<T>[];
  value: T;
  onChange: (value: T) => void;
  label: string;
  className?: string;
};

const keySteps: Record<string, number> = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };

export function GlassSegmented<T extends string>({ options, value, onChange, label, className }: GlassSegmentedProps<T>) {
  const trackRef = useRef<HTMLDivElement>(null);
  const thumbRef = useRef<HTMLSpanElement>(null);
  const buttonRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const selectedIndex = Math.max(0, options.findIndex((option) => option.value === value));

  useLayoutEffect(() => {
    const track = trackRef.current;
    const thumb = thumbRef.current;
    if (!track || !thumb) return;
    const place = () => {
      const button = buttonRefs.current[selectedIndex];
      if (!button) return;
      thumb.style.transform = `translate3d(${button.offsetLeft}px, 0, 0)`;
      thumb.style.width = `${button.offsetWidth}px`;
    };
    place();
    const frame = requestAnimationFrame(() => thumb.setAttribute("data-animated", ""));
    const observer = new ResizeObserver(place);
    observer.observe(track);
    return () => {
      cancelAnimationFrame(frame);
      observer.disconnect();
    };
  }, [selectedIndex]);

  const handleKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    const step = keySteps[event.key];
    if (!step) return;
    event.preventDefault();
    const next = (selectedIndex + step + options.length) % options.length;
    onChange(options[next].value);
    buttonRefs.current[next]?.focus();
  };

  return (
    <div role="radiogroup" aria-label={label} className={clsx(styles.base, className)}>
      <div ref={trackRef} className={styles.track}>
        <span ref={thumbRef} className={styles.thumb} aria-hidden="true" />
        {options.map((option, index) => {
          const OptionIcon = option.icon;
          const selected = index === selectedIndex;
          return (
            <button
              key={option.value}
              ref={(element) => {
                buttonRefs.current[index] = element;
              }}
              type="button"
              role="radio"
              aria-checked={selected}
              tabIndex={selected ? 0 : -1}
              className={styles.option}
              data-focused={selected || undefined}
              onClick={() => onChange(option.value)}
              onKeyDown={handleKeyDown}
            >
              <OptionIcon weight="bold" aria-hidden="true" />
              {option.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
