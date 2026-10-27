"use client";

import { useRef, useState, type CSSProperties } from "react";
import clsx from "clsx";
import { TmaxMark } from "@/components/chrome/tmax-mark";
import { useImmersive } from "@/components/providers/immersive";
import { gsap, useGSAP } from "@/lib/gsap";
import { useMediaQuery, usePrefersReducedMotion } from "@/lib/motion";
import { arenaAssets } from "./arena-assets";
import { ArenaImage } from "./arena-image";
import { arenaFigures, backdropDepth, cameraTravel, dustPlanes, passingFade, type ArenaFigure, type DustPlane } from "./arena-layout";
import styles from "./arena.module.css";

const sceneDescription =
  "A dark marble arena. Colossal marble app icons carved with the Instagram, TikTok, YouTube, X and Facebook logos turn to watch a towering black marble Tmax icon in the center.";

function planeStyle({ id, desktop, compact, phone }: ArenaFigure): CSSProperties {
  const asset = arenaAssets[id];
  const narrow = phone ?? compact;
  return {
    "--ratio": `${asset.width} / ${asset.height}`,
    "--desktop-x": desktop.x,
    "--desktop-bottom": desktop.bottom,
    "--desktop-height": desktop.height,
    "--compact-x": compact.x,
    "--compact-bottom": compact.bottom,
    "--compact-height": compact.height,
    "--phone-x": narrow.x,
    "--phone-bottom": narrow.bottom,
    "--phone-height": narrow.height,
  } as CSSProperties;
}

function DustLayer({ plane }: { plane: DustPlane }) {
  return (
    <div
      className={clsx(styles.plane, styles.dust)}
      data-depth={plane.depth}
      data-drift={plane.drift.join(" ")}
      data-passes={plane.passes}
    >
      <div className={clsx(styles.cover, "absolute inset-0", plane.className)}>
        <ArenaImage id="dust" sizes="(max-aspect-ratio: 1/1) 320vw, 100vw" />
      </div>
    </div>
  );
}

function MonumentHalo() {
  const mark = arenaAssets.monument.mark;
  if (!mark) return null;
  const style = { "--mark-x": mark.x, "--mark-y": mark.y, "--mark-w": mark.width, "--mark-h": mark.height } as CSSProperties;
  return (
    <span className={styles.halo} style={style} data-arena-halo>
      <TmaxMark className={styles.haloGlow} preserveAspectRatio="none" />
      <TmaxMark className={styles.haloCore} preserveAspectRatio="none" />
    </span>
  );
}

export function ArenaOpening() {
  const stageRef = useRef<HTMLDivElement>(null);
  const reducedMotion = usePrefersReducedMotion();
  const phone = useMediaQuery("(max-aspect-ratio: 1/1)");
  const [immersive, setImmersive] = useState(false);
  useImmersive(immersive);

  useGSAP(
    () => {
      const stage = stageRef.current;
      if (reducedMotion || !stage) return;
      const camera = { travel: 0 };
      const planes = gsap.utils.toArray<HTMLElement>("[data-depth]", stage).map((element) => {
        const [driftX = 0, driftY = 0] = (element.dataset.drift ?? "").split(" ").map(Number);
        return { element, depth: Number(element.dataset.depth), driftX, driftY, passes: element.dataset.passes === "true" };
      });
      const render = () => {
        for (const { element, depth, driftX, driftY, passes } of planes) {
          const scale = depth / (depth - camera.travel);
          element.style.transform = `translate(${(driftX * camera.travel).toFixed(3)}%, ${(driftY * camera.travel).toFixed(3)}%) scale(${scale.toFixed(4)})`;
          if (passes) element.style.opacity = gsap.utils.clamp(0, 1, (passingFade.to - scale) / (passingFade.to - passingFade.from)).toFixed(3);
        }
      };
      render();

      const timeline = gsap.timeline({
        defaults: { ease: "none" },
        scrollTrigger: {
          trigger: stage,
          start: "top top",
          end: () => `+=${window.innerHeight * (phone ? 1.7 : 2.4)}`,
          pin: true,
          scrub: true,
          invalidateOnRefresh: true,
          onToggle: (self) => setImmersive(self.isActive),
        },
      });
      timeline.to(camera, { travel: phone ? cameraTravel.phone : cameraTravel.desktop, duration: 1, ease: "power1.inOut", onUpdate: render }, 0);
      timeline.to("[data-arena-title]", { yPercent: -45, autoAlpha: 0, duration: 0.2, ease: "power2.in" }, 0.05);
      timeline.fromTo("[data-arena-aura]", { autoAlpha: 0.3 }, { autoAlpha: 1, duration: 0.7 }, 0.2);
      timeline.fromTo("[data-arena-halo]", { autoAlpha: 0 }, { autoAlpha: 1, duration: 0.45, ease: "power1.in" }, 0.5);

      return () => {
        setImmersive(false);
        for (const { element } of planes) {
          element.style.transform = "";
          element.style.opacity = "";
        }
      };
    },
    { scope: stageRef, dependencies: [reducedMotion, phone], revertOnUpdate: true },
  );

  return (
    <section aria-labelledby="social-arena-title">
      <div ref={stageRef} className={styles.stage}>
        <div className={styles.scene} role="img" aria-label={sceneDescription}>
          <div className={clsx(styles.plane, styles.cover)} data-depth={backdropDepth}>
            <ArenaImage id="arena" sizes="(max-aspect-ratio: 1/1) 320vw, 100vw" />
          </div>
          <DustLayer plane={dustPlanes.far} />
          {arenaFigures.map((figure) => (
            <div
              key={figure.id}
              className={styles.plane}
              style={planeStyle(figure)}
              data-depth={figure.depth}
              data-passes={figure.passes === true}
              data-phone={figure.phone ? "on" : "off"}
            >
              {figure.id === "monument" ? <span className={styles.aura} data-arena-aura /> : null}
              <div className={styles.figure}>
                <ArenaImage id={figure.id} sizes={figure.sizes} />
                {figure.id === "monument" ? <MonumentHalo /> : null}
              </div>
            </div>
          ))}
          <DustLayer plane={dustPlanes.near} />
        </div>
        <div className={styles.seal} aria-hidden="true" />
        <div className={styles.title} data-arena-title>
          <h3 id="social-arena-title" className="text-display text-[clamp(40px,6.2vw,100px)]">
            Big Social is <em>watching.</em>
          </h3>
        </div>
      </div>
    </section>
  );
}
