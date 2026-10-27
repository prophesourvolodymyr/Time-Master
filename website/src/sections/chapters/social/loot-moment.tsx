"use client";

import { useRef, type CSSProperties } from "react";
import { ArrowRightIcon } from "@phosphor-icons/react";
import clsx from "clsx";
import { BorderSlide } from "@/components/motion/border-slide";
import { gsap, useGSAP } from "@/lib/gsap";
import { usePrefersReducedMotion } from "@/lib/motion";
import { site } from "@/lib/site";
import { arenaAssets } from "./arena-assets";
import { ArenaImage, assetUrl, sourceSet } from "./arena-image";
import { MoltenBadge, SolarFlareRing } from "./collectibles";
import { fracture } from "./fracture";
import styles from "./loot.module.css";

const tablet = arenaAssets["tablet-tiktok"];
const tabletSizes = "(min-width: 768px) min(600px, 46vw, 74dvh), min(90vw, 44dvh)";
const { shards, cracks } = fracture([0.5, 0.5], 7, [0, 0.14, 0.34, 0.6, 1.1], 11);
const crackMask = { maskImage: `url(${assetUrl("tablet-tiktok", tablet.widths[tablet.widths.length - 1])})` } as CSSProperties;

const lines = [
  "Tmax collectibles restyle your profile: icon rings, name styles, badge skins and profile styles.",
  `${site.promo.sentence} Starts after launch.`,
];

const percent = (value: number) => `${(value * 100).toFixed(3)}%`;

function Treasure() {
  return (
    <div className={styles.treasure}>
      <span className={styles.halo} data-treasure-halo />
      <div className={styles.ring} data-treasure-ring>
        <SolarFlareRing className="size-full" />
      </div>
      <div className={styles.badge} data-treasure-badge>
        <MoltenBadge className="size-full" />
      </div>
      <p className={clsx(styles.tag, "rounded-chip bg-surface-2 px-3 py-1.5 text-[13px] text-ink-2")} data-treasure-tag>
        NFT prize · after launch
      </p>
    </div>
  );
}

function Shards() {
  return (
    <div className={styles.pieces}>
      {shards.map((shard) => (
        <div
          key={shard.polygon}
          className={styles.shard}
          data-shard
          style={{
            left: percent(shard.box.x),
            top: percent(shard.box.y),
            width: percent(shard.box.width),
            height: percent(shard.box.height),
            clipPath: shard.polygon,
            transformOrigin: shard.origin,
          }}
        >
          <picture>
            <source type="image/avif" srcSet={sourceSet("tablet-tiktok", tablet.widths, "avif")} sizes={tabletSizes} />
            <img
              src={assetUrl("tablet-tiktok", tablet.widths[tablet.widths.length - 1])}
              srcSet={sourceSet("tablet-tiktok", tablet.widths, "webp")}
              sizes={tabletSizes}
              alt=""
              loading="lazy"
              decoding="async"
              draggable={false}
              style={{
                left: percent(-shard.box.x / shard.box.width),
                top: percent(-shard.box.y / shard.box.height),
                width: percent(1 / shard.box.width),
                height: percent(1 / shard.box.height),
              }}
            />
          </picture>
        </div>
      ))}
    </div>
  );
}

function Copy() {
  return (
    <div className={clsx(styles.copy, "relative z-10 flex flex-col gap-6")}>
      <BorderSlide from="right" duration={0.9}>
        <h3 id="social-loot-title" className="text-display pb-1 text-[clamp(40px,5.2vw,84px)]">
          Their logo. <em>Your loot.</em>
        </h3>
      </BorderSlide>
      <ul className="flex flex-col gap-3">
        {lines.map((line, index) => (
          <li key={line}>
            <BorderSlide from="right" delay={0.08 * (index + 1)} duration={0.8}>
              <p className="max-w-[34ch] text-[clamp(17px,1.5vw,21px)] text-ink-2">{line}</p>
            </BorderSlide>
          </li>
        ))}
      </ul>
      <p className="sr-only">The TikTok mark, carved in marble, shatters into Tmax collectibles: the Solar flare icon ring and the Molten badge skin.</p>
    </div>
  );
}

export function LootMoment() {
  const stageRef = useRef<HTMLDivElement>(null);
  const reducedMotion = usePrefersReducedMotion();

  useGSAP(
    () => {
      const stage = stageRef.current;
      const art = stage?.querySelector<HTMLElement>("[data-loot-art]");
      if (reducedMotion || !stage || !art) return;
      const pieces = gsap.utils.toArray<HTMLElement>("[data-shard]", stage);
      const reach = () => art.clientWidth * (window.matchMedia("(min-width: 768px)").matches ? 1 : 0.7);
      const timeline = gsap.timeline({
        defaults: { ease: "none" },
        scrollTrigger: {
          trigger: stage,
          start: "top top",
          end: () => `+=${window.innerHeight * 1.6}`,
          pin: true,
          scrub: 0.6,
          invalidateOnRefresh: true,
        },
      });
      timeline.fromTo("[data-crack]", { drawSVG: "0% 0%" }, { drawSVG: "0% 100%", duration: 0.24, stagger: 0.006, ease: "power1.in" }, 0.02);
      timeline.to("[data-tablet]", { scale: 1.035, duration: 0.26, ease: "power2.in" }, 0.02);
      timeline.fromTo("[data-flash]", { autoAlpha: 0, scale: 0.4 }, { autoAlpha: 1, scale: 1, duration: 0.05, ease: "power2.out" }, 0.27);
      timeline.set("[data-intact]", { autoAlpha: 0 }, 0.3);
      timeline.set(pieces, { opacity: 1 }, 0.3);
      timeline.to("[data-cracks]", { autoAlpha: 0, duration: 0.04 }, 0.3);
      timeline.to("[data-flash]", { autoAlpha: 0, duration: 0.16 }, 0.32);
      pieces.forEach((piece, index) => {
        const shard = shards[index];
        timeline.to(
          piece,
          {
            x: () => shard.direction[0] * shard.distance * reach(),
            y: () => (shard.direction[1] * shard.distance + shard.fall) * reach(),
            rotationX: shard.spin[0],
            rotationY: shard.spin[1],
            rotationZ: shard.spin[2],
            scale: 0.55,
            duration: 0.42,
            ease: "power2.out",
          },
          0.3,
        );
        timeline.to(piece, { autoAlpha: 0, duration: 0.14 }, 0.56 + (index % 5) * 0.012);
      });
      timeline.fromTo("[data-treasure-halo]", { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.3 }, 0.34);
      timeline.fromTo("[data-treasure-ring]", { autoAlpha: 0, scale: 0.25, rotation: -140 }, { autoAlpha: 1, scale: 1, rotation: 0, duration: 0.34, ease: "back.out(1.5)" }, 0.36);
      timeline.fromTo(
        "[data-treasure-badge]",
        { autoAlpha: 0, scale: 0.3, xPercent: 120, yPercent: 140 },
        { autoAlpha: 1, scale: 1, xPercent: 0, yPercent: 0, duration: 0.3, ease: "back.out(1.6)" },
        0.46,
      );
      timeline.fromTo("[data-treasure-tag]", { autoAlpha: 0, y: 16 }, { autoAlpha: 1, y: 0, duration: 0.12 }, 0.7);
      timeline.set({}, {}, 1);
    },
    { scope: stageRef, dependencies: [reducedMotion], revertOnUpdate: true },
  );

  if (reducedMotion) {
    return (
      <section aria-labelledby="social-loot-title">
        <div className={styles.stage}>
          <div className={styles.pair} aria-hidden="true">
            <figure>
              <div className={styles.layer}>
                <ArenaImage id="tablet-tiktok" sizes="(min-width: 768px) 280px, 40vw" />
              </div>
            </figure>
            <ArrowRightIcon size={28} weight="bold" className="text-accent" />
            <figure>
              <Treasure />
            </figure>
          </div>
          <Copy />
        </div>
      </section>
    );
  }

  return (
    <section aria-labelledby="social-loot-title">
      <div ref={stageRef} className={styles.stage}>
        <div className={styles.art} data-loot-art aria-hidden="true">
          <Treasure />
          <span className={styles.flash} data-flash />
          <div className={styles.layer} data-tablet>
            <div className={styles.layer} data-intact>
              <ArenaImage id="tablet-tiktok" sizes={tabletSizes} />
            </div>
            <Shards />
            <svg className={styles.cracks} style={crackMask} viewBox="0 0 100 100" preserveAspectRatio="none" data-cracks>
              {cracks.map((crack) => (
                <path key={crack} d={crack} vectorEffect="non-scaling-stroke" data-crack />
              ))}
            </svg>
          </div>
        </div>
        <Copy />
      </div>
    </section>
  );
}
