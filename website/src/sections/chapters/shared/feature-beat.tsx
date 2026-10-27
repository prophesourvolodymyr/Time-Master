import type { ReactNode } from "react";
import clsx from "clsx";
import { appClips, type AppClipId } from "@/content/app-clips";
import { AppClip, DeviceFrame } from "@/components/media";
import { BorderSlide } from "@/components/motion/border-slide";

export type FeatureBeatProps = {
  clip: AppClipId;
  title: string;
  lines: readonly string[];
  side?: "left" | "right";
  aside?: ReactNode;
};

export function FeatureBeat({ clip, title, lines, side = "left", aside }: FeatureBeatProps) {
  const recorded = appClips[clip] !== undefined;
  const textFrom = recorded ? (side === "left" ? "right" : "left") : "bottom";
  return (
    <section
      className={clsx(
        "mx-auto grid items-center gap-10 px-5 py-24 md:gap-16 md:px-8",
        recorded ? "min-h-dvh max-w-[1400px] md:grid-cols-2" : "min-h-[70dvh] max-w-[900px] justify-items-center text-center",
      )}
    >
      {recorded ? (
        <BorderSlide from={side} duration={0.9} className={clsx("py-4", side === "right" && "md:order-2")}>
          <DeviceFrame className="mx-auto w-[min(64vw,330px)]">
            <AppClip id={clip} label={title} />
          </DeviceFrame>
        </BorderSlide>
      ) : null}
      <div className={clsx("flex flex-col gap-6", !recorded && "items-center")}>
        <BorderSlide from={textFrom} duration={0.9}>
          <h3 className="text-display text-[clamp(40px,5.2vw,84px)] pb-1">{title}</h3>
        </BorderSlide>
        <ul className="flex flex-col gap-3">
          {lines.map((line, index) => (
            <li key={line}>
              <BorderSlide from={textFrom} delay={0.08 * (index + 1)} duration={0.8}>
                <p className={clsx("max-w-[34ch] text-[clamp(17px,1.5vw,21px)] text-ink-2", !recorded && "mx-auto")}>{line}</p>
              </BorderSlide>
            </li>
          ))}
        </ul>
        {aside}
      </div>
    </section>
  );
}
