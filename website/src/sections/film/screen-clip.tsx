"use client";

import { useEffect, useRef } from "react";
import { appClips, type AppClipId } from "@/content/app-clips";

export type ScreenClipProps = {
  id: AppClipId;
  active: boolean;
  playing: boolean;
};

export function ScreenClip({ id, active, playing }: ScreenClipProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const clip = appClips[id];

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (active && playing) {
      video.currentTime = 0;
      video.play().catch(() => undefined);
    } else {
      video.pause();
    }
  }, [active, playing]);

  if (!clip) return null;

  return (
    <video
      ref={videoRef}
      data-active={active}
      src={clip.src}
      poster={clip.poster}
      muted
      loop
      playsInline
      disablePictureInPicture
      disableRemotePlayback
      preload={active ? "auto" : "none"}
      aria-hidden="true"
    />
  );
}
