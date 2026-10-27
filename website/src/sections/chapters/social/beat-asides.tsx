import { BorderSlide, type BorderEdge } from "@/components/motion/border-slide";
import { FadeImage } from "./arena-image";

const tiers = ["Iron", "Bronze", "Silver", "Gold", "Diamond", "Champion"] as const;
const poses = ["Front double biceps", "Side physique", "Rear double biceps"] as const;

export function TierLadder({ from }: { from: BorderEdge }) {
  return (
    <BorderSlide from={from} delay={0.3} duration={0.8}>
      <ol className="flex flex-wrap items-end gap-x-3 gap-y-4" aria-label="Ranked tiers, from Iron to Champion">
        {tiers.map((tier) => (
          <li key={tier} className="flex w-14 flex-col items-center gap-1.5">
            <FadeImage stem={`tier-${tier.toLowerCase()}`} widths={[96, 192]} width={192} height={192} sizes="56px" className="size-12 md:size-14" />
            <span className="text-[12px] text-ink-3">{tier}</span>
          </li>
        ))}
      </ol>
    </BorderSlide>
  );
}

export function PoseChips({ from }: { from: BorderEdge }) {
  return (
    <BorderSlide from={from} delay={0.3} duration={0.8}>
      <ul className="flex flex-wrap gap-2" aria-label="The three Physique Duel poses">
        {poses.map((pose) => (
          <li key={pose} className="rounded-chip bg-surface-2 px-3 py-2 text-[14px] text-ink-2">
            {pose}
          </li>
        ))}
      </ul>
    </BorderSlide>
  );
}
