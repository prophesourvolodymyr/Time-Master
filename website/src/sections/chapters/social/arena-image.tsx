"use client";

import { useCallback, useState } from "react";
import clsx from "clsx";
import { arenaAssets, type ArenaAssetId } from "./arena-assets";

const mediaRoot = "/media/chapters/social";

export function sourceSet(stem: string, widths: readonly number[], format: "avif" | "webp") {
  return widths.map((width) => `${mediaRoot}/${stem}-${width}.${format} ${width}w`).join(", ");
}

export function assetUrl(stem: string, width: number, format: "avif" | "webp" = "webp") {
  return `${mediaRoot}/${stem}-${width}.${format}`;
}

export type FadeImageProps = {
  stem: string;
  widths: readonly number[];
  width: number;
  height: number;
  sizes: string;
  alt?: string;
  className?: string;
};

export function FadeImage({ stem, widths, width, height, sizes, alt = "", className }: FadeImageProps) {
  const [loaded, setLoaded] = useState(false);
  const settle = useCallback((image: HTMLImageElement | null) => {
    if (image?.complete && image.naturalWidth > 0) setLoaded(true);
  }, []);

  return (
    <picture>
      <source type="image/avif" srcSet={sourceSet(stem, widths, "avif")} sizes={sizes} />
      <img
        ref={settle}
        src={assetUrl(stem, widths[widths.length - 1])}
        srcSet={sourceSet(stem, widths, "webp")}
        sizes={sizes}
        width={width}
        height={height}
        alt={alt}
        loading="lazy"
        decoding="async"
        draggable={false}
        onLoad={() => setLoaded(true)}
        className={clsx("transition-opacity duration-700 ease-out", loaded ? "opacity-100" : "opacity-0", className)}
      />
    </picture>
  );
}

export function ArenaImage({ id, sizes, className }: { id: ArenaAssetId; sizes: string; className?: string }) {
  const asset = arenaAssets[id];
  return <FadeImage stem={id} widths={asset.widths} width={asset.width} height={asset.height} sizes={sizes} className={className} />;
}
