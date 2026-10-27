import { gsap } from "@/lib/gsap";
import type { TalosPose } from "./talos-pose";

export type StagePose = { x: number; y: number; scale: number; turn: number };

export type TalosStation = "intro" | "device-left" | "device-right" | "solo-left" | "solo-right" | "demo";

type PoseSet = Record<TalosStation, StagePose>;

const widePoses: PoseSet = {
  intro: { x: 0, y: 4, scale: 1, turn: 0.32 },
  "device-left": { x: -5, y: 19, scale: 0.5, turn: -0.85 },
  "device-right": { x: 3, y: 19, scale: 0.5, turn: 0.85 },
  "solo-left": { x: -24, y: 5, scale: 0.82, turn: 0.72 },
  "solo-right": { x: 24, y: 5, scale: 0.82, turn: -0.72 },
  demo: { x: 21, y: 3, scale: 0.9, turn: -0.46 },
};

const narrowPoses: PoseSet = {
  intro: { x: 0, y: 9, scale: 1, turn: 0.32 },
  "device-left": { x: 37, y: -9, scale: 0.34, turn: -0.72 },
  "device-right": { x: -37, y: -9, scale: 0.34, turn: 0.72 },
  "solo-left": { x: -14, y: -6, scale: 0.98, turn: 0.5 },
  "solo-right": { x: 14, y: -6, scale: 0.98, turn: -0.5 },
  demo: { x: -22, y: -25, scale: 0.44, turn: 0.35 },
};

export function stationPoses(stations: readonly TalosStation[], wide: boolean) {
  const set = wide ? widePoses : narrowPoses;
  return stations.map((station) => set[station]);
}

export function buildPathTimeline(stage: HTMLElement, pose: TalosPose, poses: readonly StagePose[]) {
  const timeline = gsap.timeline({ paused: true });
  const [first] = poses;
  timeline.set(stage, { x: `${first.x}vw`, y: `${first.y}vh`, scale: first.scale }, 0).set(pose, { turn: first.turn }, 0);
  poses.slice(1).forEach((next, index) => {
    const previous = poses[index];
    const crossing = previous.x !== next.x;
    const lift = Math.min(previous.y, next.y) - (crossing ? 7 : 0);
    const depth = Math.min(previous.scale, next.scale) * (crossing ? 0.86 : 1);
    timeline
      .to(stage, { x: `${next.x}vw`, duration: 1, ease: "power2.inOut" }, index)
      .to(stage, { y: `${lift}vh`, scale: depth, duration: 0.5, ease: "sine.out" }, index)
      .to(stage, { y: `${next.y}vh`, scale: next.scale, duration: 0.5, ease: "sine.in" }, index + 0.5)
      .to(pose, { turn: next.turn, duration: 1, ease: "power1.inOut" }, index);
  });
  return timeline;
}

export function timeAtScroll(scroll: number, marks: readonly number[]) {
  if (marks.length === 0 || scroll <= marks[0]) return 0;
  for (let index = 1; index < marks.length; index += 1) {
    if (scroll <= marks[index]) {
      const span = Math.max(1, marks[index] - marks[index - 1]);
      return index - 1 + (scroll - marks[index - 1]) / span;
    }
  }
  return marks.length - 1;
}

export function snapTarget(scroll: number, rests: readonly number[], direction: number, viewport: number) {
  if (rests.length < 2 || scroll < rests[0] - 2 || scroll > rests[rests.length - 1] + 2) return undefined;
  const nearest = rests.reduce((best, rest) => (Math.abs(rest - scroll) < Math.abs(best - scroll) ? rest : best));
  const offset = Math.abs(nearest - scroll);
  if (offset < 3) return undefined;
  if (offset < viewport * 0.08) return nearest;
  return direction >= 0 ? rests.find((rest) => rest > scroll) : rests.findLast((rest) => rest < scroll);
}

export function stepTarget(scroll: number, rests: readonly number[], forward: boolean, reach: number) {
  if (rests.length < 2) return undefined;
  const first = rests[0];
  const last = rests[rests.length - 1];
  if (forward) return scroll < first - reach || scroll > last - 2 ? undefined : rests.find((rest) => rest > Math.max(scroll, first) + 2);
  return scroll < first + 2 || scroll > last + 2 ? undefined : rests.findLast((rest) => rest < scroll - 2);
}
