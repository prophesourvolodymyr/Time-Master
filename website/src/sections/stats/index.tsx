"use client";

import { useState } from "react";
import clsx from "clsx";
import { stats, statModes, type StatMode } from "@/content/stats";
import { BorderSlide } from "@/components/motion/border-slide";
import { CardSurface, SegmentedControl } from "@/components/ui";
import { StatNumber } from "./stat-number";

export function StatsSection() {
  const [mode, setMode] = useState<StatMode>("collection");

  return (
    <section id="stats" aria-labelledby="stats-title" className="mx-auto max-w-[1400px] px-5 py-28 md:px-8 md:py-36">
      <div className="mb-12 flex flex-col items-center gap-7 text-center">
        <BorderSlide from="bottom">
          <h2 id="stats-title" className="text-display text-[clamp(44px,7vw,112px)] pb-1">
            The damage report.
          </h2>
        </BorderSlide>
        <SegmentedControl label="Show numbers" options={statModes} value={mode} onChange={setMode} />
      </div>
      <ul className="grid gap-3 sm:grid-cols-2 md:grid-cols-6 md:gap-4">
        {stats.map((stat, index) => {
          const figure = stat.figures[mode];
          return (
            <CardSurface
              as="li"
              key={stat.label}
              emphasized={stat.emphasized}
              className={clsx("flex min-h-[230px] flex-col justify-between gap-4 p-6 md:col-span-2", index === 6 && "md:col-start-2")}
            >
              <span className="font-display text-[15px] font-black text-ink-2">{stat.label}</span>
              <span className="text-display whitespace-nowrap text-[clamp(30px,3.5vw,56px)]">
                <StatNumber figure={figure} />
              </span>
              <span className="flex flex-col gap-1">
                <span className="font-display text-[22px] font-black">{stat.outcome}</span>
                <span className="text-[13px] text-ink-3">{stat.joke}</span>
              </span>
            </CardSurface>
          );
        })}
      </ul>
      <p className="mt-8 text-center text-[13px] text-ink-3">Playful math. Real gains vary.</p>
    </section>
  );
}
