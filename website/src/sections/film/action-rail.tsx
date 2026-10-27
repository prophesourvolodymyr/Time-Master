import { BookmarkSimpleIcon, ChatCircleIcon, HeartIcon, ShareFatIcon } from "@phosphor-icons/react";
import styles from "./film.module.css";

const compact = new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 1 });

const items = [
  { icon: HeartIcon, base: 48_200, step: 9_700 },
  { icon: ChatCircleIcon, base: 1_340, step: 410 },
  { icon: ShareFatIcon, base: 3_900, step: 1_150 },
  { icon: BookmarkSimpleIcon, base: 6_100, step: 1_800 },
];

export function ActionRail({ step }: { step: number }) {
  return (
    <ul className={styles.rail} data-rail aria-hidden="true">
      {items.map(({ icon: Icon, base, step: increment }, index) => (
        <li key={index} className={styles.railItem}>
          <span className={styles.railButton} data-hot={(index === 0 && step > 0) || undefined}>
            <Icon weight={index === 0 && step > 0 ? "fill" : "bold"} />
          </span>
          {compact.format(base + increment * step * (1 + step / 6))}
        </li>
      ))}
    </ul>
  );
}
