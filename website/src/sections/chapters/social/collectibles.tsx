import { useId } from "react";
import { TmaxMark } from "@/components/chrome/tmax-mark";
import styles from "./loot.module.css";

const solarFlare = ["#ff6b24", "#ffd140", "#ffffff"] as const;
const molten = ["#fc401a", "#ffa32e", "#ffe357"] as const;
const ringWidth = 0.045;

const rays = Array.from({ length: 10 }, (_, index) => {
  const angle = (index * Math.PI) / 5;
  const major = index % 2 === 0;
  const outer = major ? 0.55 : 0.51;
  return {
    x1: Math.cos(angle) * 0.46,
    y1: Math.sin(angle) * 0.46,
    x2: Math.cos(angle) * outer,
    y2: Math.sin(angle) * outer,
    color: solarFlare[index % solarFlare.length],
    opacity: major ? 0.95 : 0.62,
    width: ringWidth * (major ? 0.72 : 0.44),
  };
});

export function SolarFlareRing({ className }: { className?: string }) {
  return (
    <svg viewBox="-0.5 -0.5 1 1" className={className} role="img" aria-label="Solar flare icon ring">
      <circle r="0.5" fill="#050505" />
      <TmaxMark x="-0.3" y="-0.3" width="0.6" height="0.6" color="#fff" />
      <g className={styles.rays}>
        {rays.map((ray) => (
          <line
            key={`${ray.x1}-${ray.y1}`}
            x1={ray.x1}
            y1={ray.y1}
            x2={ray.x2}
            y2={ray.y2}
            stroke={ray.color}
            strokeOpacity={ray.opacity}
            strokeWidth={ray.width}
            strokeLinecap="round"
          />
        ))}
      </g>
      <circle r="0.44" fill="none" stroke={solarFlare[0]} strokeWidth={ringWidth * 1.16} />
      <g className={styles.flare}>
        <ellipse rx="0.54" ry="0.14" transform="rotate(38)" fill="none" stroke={solarFlare[1]} strokeWidth={ringWidth * 0.7} strokeLinecap="round" />
      </g>
    </svg>
  );
}

export function MoltenBadge({ className }: { className?: string }) {
  const id = useId();
  return (
    <svg viewBox="0 0 100 100" className={className} role="img" aria-label="Molten badge skin">
      <defs>
        <linearGradient id={`${id}-fill`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={molten[0]} />
          <stop offset="0.5" stopColor={molten[1]} />
          <stop offset="1" stopColor={molten[2]} />
        </linearGradient>
        <linearGradient id={`${id}-shine`} x1="0" y1="0.15" x2="1" y2="0.85">
          <stop offset="0.3" stopColor="#fff" stopOpacity="0" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0.55" />
          <stop offset="0.7" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
        <path id={`${id}-shield`} d="M50 5c11 6 24 9 38 9v32c0 26-16 42-38 50C28 88 12 72 12 46V14c14 0 27-3 38-9Z" />
      </defs>
      <use href={`#${id}-shield`} fill={`url(#${id}-fill)`} />
      <use href={`#${id}-shield`} fill={`url(#${id}-shine)`} />
      <use href={`#${id}-shield`} fill="none" stroke="#fff" strokeOpacity="0.36" strokeWidth="2.4" />
      <g fill="#fff" fillOpacity="0.96">
        <rect x="40" y="42" width="6" height="10" rx="1.6" />
        <rect x="47" y="36" width="6" height="16" rx="1.6" />
        <rect x="54" y="30" width="6" height="22" rx="1.6" />
        <rect x="25" y="58" width="20" height="2.6" rx="1.3" />
        <rect x="48.5" y="58" width="14" height="2.6" rx="1.3" />
        <rect x="66" y="58" width="9" height="2.6" rx="1.3" />
      </g>
    </svg>
  );
}
