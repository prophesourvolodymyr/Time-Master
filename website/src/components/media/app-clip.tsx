"use client";

import { useEffect, useRef } from "react";
import { appClips, type AppClipId } from "@/content/app-clips";
import { usePrefersReducedMotion } from "@/lib/motion";

export type AppClipProps = {
  id: AppClipId;
  className?: string;
  priority?: boolean;
  label?: string;
  active?: boolean;
};

export function AppClip({ id, className, priority = false, label, active = true }: AppClipProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const reducedMotion = usePrefersReducedMotion();
  const clip = appClips[id];

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (reducedMotion || !active) {
      video.pause();
      return;
    }
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          video.preload = "auto";
          video.play().catch(() => undefined);
        } else {
          video.pause();
        }
      },
      { threshold: 0.15 },
    );
    observer.observe(video);
    return () => observer.disconnect();
  }, [reducedMotion, active, clip]);

  if (!clip) return null;

  return (
    <video
      ref={videoRef}
      className={className}
      src={clip.src}
      poster={clip.poster}
      width={clip.width}
      height={clip.height}
      muted
      loop
      playsInline
      disablePictureInPicture
      disableRemotePlayback
      preload={priority ? "auto" : "none"}
      aria-label={label}
      aria-hidden={label ? undefined : true}
    />
  );
}
