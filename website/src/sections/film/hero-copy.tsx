"use client";

import type { Ref } from "react";
import { ArrowDownIcon } from "@phosphor-icons/react";
import { ActionButton } from "@/components/ui";
import { site } from "@/lib/site";
import { MemberCounter } from "./member-counter";
import styles from "./film.module.css";

export type HeroCopyProps = {
  ref?: Ref<HTMLDivElement>;
  onInstall: () => void;
};

export function HeroCopy({ ref, onInstall }: HeroCopyProps) {
  return (
    <div ref={ref} className={styles.heroCopy}>
      <h1 className={styles.headline} data-hero-part>
        A Fitness <em>Everything</em> App You Dreamed Of
      </h1>
      <div className="flex flex-col gap-4" data-hero-part>
        <div className="flex flex-wrap items-center gap-4">
          <MemberCounter />
          <ActionButton prominent size={58} paddingX={22} icon={<ArrowDownIcon weight="bold" />} iconPosition="trailing" onClick={onInstall}>
            Install Now
          </ActionButton>
        </div>
        <p className="max-w-[40ch] text-[14px] text-ink-2">{site.promo.sentence}</p>
      </div>
    </div>
  );
}
