"use client";

import { useRef, useState, type PointerEvent } from "react";
import Image from "next/image";
import clsx from "clsx";
import {
  BarbellIcon,
  BooksIcon,
  CoinIcon,
  CoinsIcon,
  CreditCardIcon,
  CrownIcon,
  HourglassIcon,
  PiggyBankIcon,
  StackIcon,
  SwordIcon,
  TrendUpIcon,
  UserIcon,
  UsersThreeIcon,
  type Icon,
} from "@phosphor-icons/react";
import { stats, statModes, type StatFigure, type StatId, type StatMode, type StatOutcome, type StatReveal, type StatSize } from "@/content/stats";
import { CardSurface, GlassSegmented } from "@/components/ui";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import { RollingNumber } from "./rolling-number";
import styles from "./stats.module.css";

const modeIcons: Record<StatMode, Icon> = { person: UserIcon, collection: UsersThreeIcon };
const modeOptions = statModes.map((mode) => ({ ...mode, icon: modeIcons[mode.value] }));

const labelIcons: Record<StatId, Icon> = {
  nft: CoinIcon,
  muscle: BarbellIcon,
  procrastination: HourglassIcon,
  subscriptions: CreditCardIcon,
  rivals: SwordIcon,
  community: UsersThreeIcon,
  "main-character": CrownIcon,
  database: BooksIcon,
};

const outcomeIcons: Record<StatOutcome, Icon> = {
  Saved: PiggyBankIcon,
  Collected: StackIcon,
  Made: CoinsIcon,
  Gained: TrendUpIcon,
};

const compact = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 });
const grouping = new Intl.NumberFormat("en-US");

function format(figure: StatFigure) {
  if (figure.text) return figure.text;
  const number = figure.value >= 100_000 ? compact.format(figure.value) : grouping.format(figure.value);
  return `${figure.prefix ?? ""}${number}${figure.plus ? "+" : ""}${figure.suffix ?? ""}`;
}

const reveals: Record<StatReveal, readonly [gsap.TweenVars, gsap.TweenVars]> = {
  rise: [{ y: 140, autoAlpha: 0, filter: "blur(18px)" }, { y: 0, autoAlpha: 1, filter: "blur(0px)" }],
  iris: [{ clipPath: "circle(0% at 50% 50%)" }, { clipPath: "circle(150% at 50% 50%)" }],
  wipe: [{ clipPath: "inset(100% 0% 0% 0% round 28px)" }, { clipPath: "inset(0% 0% 0% 0% round 28px)" }],
  tilt: [{ rotateX: 35, y: 90, autoAlpha: 0, transformPerspective: 1100 }, { rotateX: 0, y: 0, autoAlpha: 1 }],
  zoom: [{ scale: 0.78, autoAlpha: 0 }, { scale: 1, autoAlpha: 1 }],
  slide: [{ xPercent: -24, skewX: 10, autoAlpha: 0 }, { xPercent: 0, skewX: 0, autoAlpha: 1 }],
};

const imageSizes: Record<StatSize, string> = {
  hero: "(min-width: 1024px) 50vw, 100vw",
  wide: "(min-width: 1024px) 50vw, 100vw",
  banner: "(min-width: 1024px) 40vw, 100vw",
  tall: "(min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw",
  regular: "(min-width: 1024px) 25vw, (min-width: 640px) 50vw, 100vw",
};

function lean(event: PointerEvent<HTMLElement>) {
  if (event.pointerType !== "mouse") return;
  const card = event.currentTarget;
  const rect = card.getBoundingClientRect();
  const x = (event.clientX - rect.left) / rect.width;
  const y = (event.clientY - rect.top) / rect.height;
  card.style.setProperty("--glow-x", `${(x * 100).toFixed(1)}%`);
  card.style.setProperty("--glow-y", `${(y * 100).toFixed(1)}%`);
  card.style.setProperty("--lean-x", `${((0.5 - y) * 6).toFixed(2)}deg`);
  card.style.setProperty("--lean-y", `${((x - 0.5) * 8).toFixed(2)}deg`);
}

function settle(event: PointerEvent<HTMLElement>) {
  const card = event.currentTarget;
  card.style.setProperty("--lean-x", "0deg");
  card.style.setProperty("--lean-y", "0deg");
}

export function StatsSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const [mode, setMode] = useState<StatMode>("collection");
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      if (reducedMotion) return;
      gsap.from("[data-stats-head]", {
        yPercent: 40,
        autoAlpha: 0,
        stagger: 0.1,
        duration: 1.1,
        ease: "expo.out",
        scrollTrigger: { trigger: sectionRef.current, start: "top 78%" },
      });
      for (const cell of gsap.utils.toArray<HTMLElement>("[data-stat]")) {
        const [from, to] = reveals[cell.dataset.reveal as StatReveal];
        gsap.fromTo(cell, from, { ...to, ease: "power2.out", scrollTrigger: { trigger: cell, start: "top 96%", end: "top 55%", scrub: 0.7 } });
        const art = cell.querySelector("[data-art]");
        if (art) {
          gsap.fromTo(art, { autoAlpha: 0, scale: 1.18 }, { autoAlpha: 1, scale: 1, ease: "power1.out", scrollTrigger: { trigger: cell, start: "top 84%", end: "top 30%", scrub: 0.9 } });
        }
        const drift = cell.querySelector("[data-drift]");
        if (drift) {
          gsap.fromTo(drift, { yPercent: 6 }, { yPercent: -6, ease: "none", scrollTrigger: { trigger: cell, start: "top bottom", end: "bottom top", scrub: true } });
        }
      }
    },
    { scope: sectionRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  return (
    <section ref={sectionRef} id="stats" aria-labelledby="stats-title" className={styles.section}>
      <div className={styles.head}>
        <h2 id="stats-title" className="text-display text-[clamp(48px,8vw,132px)] pb-1" data-stats-head>
          The damage report<span className="text-accent">.</span>
        </h2>
        <div data-stats-head>
          <GlassSegmented label="Show numbers" options={modeOptions} value={mode} onChange={setMode} />
        </div>
      </div>
      <ul className={styles.grid}>
        {stats.map((stat) => {
          const LabelIcon = labelIcons[stat.id];
          const OutcomeIcon = outcomeIcons[stat.outcome];
          return (
            <li key={stat.id} className={clsx(styles.cell, styles[stat.size])} data-stat data-reveal={stat.reveal}>
              <CardSurface className={styles.card} emphasized={stat.accent} onPointerMove={lean} onPointerLeave={settle}>
                <div className={styles.artWindow} aria-hidden="true">
                  <div className={styles.drift} data-drift>
                    <div className={styles.art} data-art>
                      <Image src={stat.image.src} alt="" fill sizes={imageSizes[stat.size]} />
                    </div>
                  </div>
                </div>
                <span className={styles.glow} aria-hidden="true" />
                <span className={styles.label}>
                  <LabelIcon weight="bold" aria-hidden="true" />
                  {stat.label}
                </span>
                <span className={clsx(styles.figure, stat.accent && styles.accentFigure)}>
                  <RollingNumber text={format(stat.figures[mode])} />
                </span>
                <span className={styles.outcome}>
                  <OutcomeIcon weight="fill" aria-hidden="true" />
                  {stat.outcome}
                </span>
              </CardSurface>
            </li>
          );
        })}
      </ul>
      <p className={styles.note} data-stats-head>
        Playful math. Real gains vary.
      </p>
    </section>
  );
}
