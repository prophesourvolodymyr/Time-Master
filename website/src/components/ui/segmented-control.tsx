"use client";

import { useLayoutEffect, useRef, type CSSProperties, type KeyboardEvent } from "react";
import clsx from "clsx";
import { SelectionButton } from "./selection-button";
import styles from "./selection.module.css";

export type SegmentedOption<T extends string> = {
  value: T;
  label: string;
};

export type SegmentedControlProps<T extends string> = {
  options: readonly SegmentedOption<T>[];
  value: T;
  onChange: (value: T) => void;
  label: string;
  className?: string;
};

const keySteps: Record<string, number> = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };

export function SegmentedControl<T extends string>({ options, value, onChange, label, className }: SegmentedControlProps<T>) {
  const groupRef = useRef<HTMLDivElement>(null);
  const buttonRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const selectedIndex = Math.max(0, options.findIndex((option) => option.value === value));

  useLayoutEffect(() => {
    const group = groupRef.current;
    if (!group) return;
    const place = () => {
      const button = buttonRefs.current[selectedIndex];
      if (!button) return;
      group.style.setProperty("--indicator-x", `${button.offsetLeft}px`);
      group.style.setProperty("--indicator-width", `${button.offsetWidth}px`);
    };
    place();
    const observer = new ResizeObserver(place);
    observer.observe(group);
    return () => observer.disconnect();
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
    <div ref={groupRef} role="radiogroup" aria-label={label} className={clsx(styles.segmented, className)} style={{} as CSSProperties}>
      <span className={styles.indicator} aria-hidden="true" />
      {options.map((option, index) => (
        <SelectionButton
          key={option.value}
          ref={(element) => {
            buttonRefs.current[index] = element;
          }}
          role="radio"
          aria-checked={index === selectedIndex}
          tabIndex={index === selectedIndex ? 0 : -1}
          selected={index === selectedIndex}
          onClick={() => onChange(option.value)}
          onKeyDown={handleKeyDown}
        >
          {option.label}
        </SelectionButton>
      ))}
    </div>
  );
}
