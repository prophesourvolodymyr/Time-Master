import type { ArenaAssetId } from "./arena-assets";

export type Placement = {
  x: number;
  bottom: number;
  height: number;
};

export type ArenaFigure = {
  id: ArenaAssetId;
  depth: number;
  desktop: Placement;
  compact: Placement;
  phone: Placement | null;
  sizes: string;
  passes?: boolean;
};

export const backdropDepth = 8.6;

export type DustPlane = {
  depth: number;
  drift: readonly [number, number];
  className: string;
  passes: boolean;
};

export const dustPlanes = {
  far: { depth: 5.2, drift: [-4, -2.5], className: "-scale-x-100 opacity-35", passes: false },
  near: { depth: 2.3, drift: [5, -3.5], className: "opacity-55", passes: true },
} as const satisfies Record<string, DustPlane>;

export const cameraTravel = { desktop: 1.9, phone: 1.5 } as const;

export const passingFade = { from: 1.75, to: 2.5 } as const;

export const arenaFigures: readonly ArenaFigure[] = [
  {
    id: "spectator-facebook",
    depth: 6.6,
    desktop: { x: 35, bottom: 66, height: 28 },
    compact: { x: 36, bottom: 64, height: 25 },
    phone: { x: 24, bottom: 54, height: 17 },
    sizes: "(max-aspect-ratio: 1/1) 20vw, 20vh",
  },
  {
    id: "monument",
    depth: 5.6,
    desktop: { x: 50, bottom: 80, height: 52 },
    compact: { x: 50, bottom: 78, height: 46 },
    phone: { x: 54, bottom: 68, height: 30 },
    sizes: "(max-aspect-ratio: 1/1) 60vw, 56vh",
  },
  {
    id: "spectator-tiktok",
    depth: 4,
    desktop: { x: 22, bottom: 86, height: 44 },
    compact: { x: 26, bottom: 84, height: 40 },
    phone: { x: 17, bottom: 86, height: 26 },
    sizes: "(max-aspect-ratio: 1/1) 34vw, 32vh",
  },
  {
    id: "spectator-x",
    depth: 4,
    desktop: { x: 77, bottom: 86, height: 44 },
    compact: { x: 74, bottom: 84, height: 40 },
    phone: { x: 83, bottom: 86, height: 26 },
    sizes: "(max-aspect-ratio: 1/1) 34vw, 32vh",
  },
  {
    id: "spectator-instagram",
    depth: 2.8,
    desktop: { x: 10, bottom: 104, height: 54 },
    compact: { x: 15, bottom: 108, height: 46 },
    phone: null,
    sizes: "58vh",
    passes: true,
  },
  {
    id: "spectator-youtube",
    depth: 2.8,
    desktop: { x: 91, bottom: 104, height: 54 },
    compact: { x: 83, bottom: 108, height: 46 },
    phone: null,
    sizes: "58vh",
    passes: true,
  },
];
