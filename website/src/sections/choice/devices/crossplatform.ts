import type { ScreenFrame } from "./devices";

export type Slot = {
  x: number;
  y: number;
  z: number;
  scale: number;
  tiltX: number;
  turnY: number;
};

export type FamilyMember = "iphone" | "android" | "laptop" | "monitor" | "watch";

export type FamilyLayout = Record<FamilyMember, Slot>;

export const familyLayouts: Record<"wide" | "compact", FamilyLayout> = {
  wide: {
    monitor: { x: 0.45, y: 0.42, z: -1.5, scale: 0.92, tiltX: 0, turnY: -0.12 },
    laptop: { x: -0.8, y: -0.82, z: 0.35, scale: 0.78, tiltX: 0.42, turnY: 0.18 },
    iphone: { x: 1.42, y: -0.6, z: 1, scale: 0.4, tiltX: 0, turnY: -0.2 },
    android: { x: -2.55, y: -0.55, z: 0.9, scale: 0.4, tiltX: 0, turnY: 0.28 },
    watch: { x: 2.3, y: -0.82, z: 1.25, scale: 0.95, tiltX: 0.18, turnY: -0.35 },
  },
  compact: {
    monitor: { x: 0, y: 1.02, z: -1.2, scale: 0.5, tiltX: 0, turnY: 0 },
    laptop: { x: 0, y: -0.24, z: 0.15, scale: 0.46, tiltX: 0.42, turnY: 0 },
    iphone: { x: 0.74, y: -0.86, z: 1.05, scale: 0.24, tiltX: 0, turnY: -0.18 },
    android: { x: -0.74, y: -0.86, z: 1.05, scale: 0.24, tiltX: 0, turnY: 0.18 },
    watch: { x: 0, y: -0.98, z: 1.3, scale: 0.48, tiltX: 0.15, turnY: 0 },
  },
};

export const revealStart: Record<Exclude<FamilyMember, "iphone">, number> = {
  laptop: 0.3,
  monitor: 0.42,
  android: 0.55,
  watch: 0.65,
};

export type LogoClock = { start: number | null };

const flareIn = 0.16;
const glowUntil = 0.95;
const flashUntil = 1.1;
const settle = 0.35;

export function logoSequence(clock: LogoClock, reveal: number, time: number, playing: boolean): ScreenFrame {
  if (reveal < 0.97) {
    if (reveal < 0.4) clock.start = null;
    return { phase: "off", playing: false, brightness: 0 };
  }
  if (clock.start === null) clock.start = time;
  const elapsed = time - clock.start;
  if (elapsed < flareIn) return { phase: "logo", playing: false, brightness: (elapsed / flareIn) * 1.7 };
  if (elapsed < glowUntil) return { phase: "logo", playing: false, brightness: 1.7 - ((elapsed - flareIn) / (glowUntil - flareIn)) * 0.7 };
  if (elapsed < flashUntil) return { phase: "logo", playing: false, brightness: 1 + ((elapsed - glowUntil) / (flashUntil - glowUntil)) * 1.6 };
  const fade = Math.min(1, (elapsed - flashUntil) / settle);
  return { phase: "media", playing, brightness: 2.4 - 1.4 * fade };
}
