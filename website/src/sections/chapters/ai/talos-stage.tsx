"use client";

import { useRef, useState, useSyncExternalStore, type Ref } from "react";
import dynamic from "next/dynamic";
import Image from "next/image";
import clsx from "clsx";
import { gsap, useGSAP } from "@/lib/gsap";
import type { TalosPose } from "./talos-pose";
import styles from "./ai-chapter.module.css";

const TalosCanvas = dynamic(() => import("./talos-canvas"), { ssr: false });

export const talosPosterSrc = "/media/chapters/ai/talos-poster.webp";

let webglSupport: boolean | undefined;

function detectWebGL() {
  if (webglSupport === undefined) {
    const canvas = document.createElement("canvas");
    webglSupport = Boolean(canvas.getContext("webgl2") ?? canvas.getContext("webgl"));
  }
  return webglSupport;
}

const noSubscription = () => () => undefined;

export function TalosPoster({ className, posterRef }: { className?: string; posterRef?: Ref<HTMLImageElement> }) {
  return (
    <Image
      ref={posterRef}
      src={talosPosterSrc}
      alt=""
      width={1000}
      height={1600}
      sizes="(min-width: 768px) 56dvh, 72dvh"
      className={clsx(styles.poster, className)}
    />
  );
}

export type TalosStageProps = {
  pose: TalosPose;
  stageRef: Ref<HTMLDivElement>;
  near: boolean;
  active: boolean;
  onModelReady: () => void;
};

export function TalosStage({ pose, stageRef, near, active, onModelReady }: TalosStageProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const posterRef = useRef<HTMLImageElement>(null);
  const [ready, setReady] = useState(false);
  const webgl = useSyncExternalStore(noSubscription, detectWebGL, () => false);

  useGSAP(
    () => {
      if (ready || !active) return;
      const poster = posterRef.current;
      if (!poster) return;
      const paint = () => {
        poster.style.opacity = String(Math.min(1, pose.light + pose.flash));
        poster.style.filter = `brightness(${1 + pose.flash * 0.25})`;
      };
      paint();
      gsap.ticker.add(paint);
      return () => gsap.ticker.remove(paint);
    },
    { scope: rootRef, dependencies: [ready, active, pose], revertOnUpdate: true },
  );

  return (
    <div className={styles.stageTrack} aria-hidden="true">
      <div ref={rootRef} className={styles.stageLayer}>
        <div ref={stageRef} className={styles.stage}>
          <TalosPoster posterRef={posterRef} className={clsx(ready && styles.posterHidden)} />
          {near && webgl ? (
            <TalosCanvas
              pose={pose}
              active={active}
              onReady={() => {
                setReady(true);
                onModelReady();
              }}
              className={clsx(styles.canvas, ready && styles.canvasReady)}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
