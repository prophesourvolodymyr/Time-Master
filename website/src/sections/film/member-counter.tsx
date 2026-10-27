"use client";

import { useSyncExternalStore } from "react";
import { site } from "@/lib/site";
import styles from "./film.module.css";

const baseMembers = 27_726;
const epoch = Date.UTC(2026, 9, 26, 12);
const growth = 50_000;
const growthSeconds = 4 * 24 * 60 * 60;

function membersAt(time: number) {
  const elapsed = Math.max(0, (time - epoch) / 1000);
  return baseMembers + Math.floor(growth * Math.log1p(elapsed / growthSeconds));
}

function subscribe(onChange: () => void) {
  const timer = window.setInterval(onChange, 1000);
  return () => window.clearInterval(timer);
}

export function MemberCounter() {
  const members = useSyncExternalStore(subscribe, () => membersAt(Date.now()), () => baseMembers);
  const text = members.toLocaleString("en-US");

  return (
    <div className={styles.counter}>
      <span className={styles.tag} aria-hidden="true">
        {site.promo.range}
      </span>
      <span className={styles.live} aria-hidden="true" />
      <span className={styles.odometer} aria-hidden="true">
        {[...text].map((character, index) => {
          const key = text.length - index;
          if (!/\d/.test(character)) return <span key={key}>{character}</span>;
          return (
            <span key={key} className={styles.digit} style={{ transform: `translateY(-${Number(character)}em)` }}>
              {"0123456789".split("").map((digit) => (
                <span key={digit}>{digit}</span>
              ))}
            </span>
          );
        })}
      </span>
      <span className="font-body text-[13px] text-ink-2">joined</span>
      <span className="sr-only">
        {text} people joined. {site.promo.sentence}
      </span>
    </div>
  );
}
