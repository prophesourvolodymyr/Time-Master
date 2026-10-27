import { NAVIGATION_ORDER } from "../seed/demo.mjs";

export const VANCOUVER = [49.2888, -123.1111];

export const pause = (seconds) => ({ op: "sleep", seconds });
export const tap = (target, after = 0.6) => ({ op: "tap", ...target, after });
export const wait = (target, timeout = 10) => ({ op: "wait", ...target, timeout });
export const quiescence = (enabled) => ({ op: "quiescence", enabled });

/** A deliberate finger drag; a short `hold` stops the scroll without momentum. */
export const drag = (from, to, { velocity = 700, hold = 0.08, after = 0.7 } = {}) => ({
  op: "drag", point: from, to: { point: to }, velocity, hold, after,
});

/** Types like a person: one key at a time. */
export const type = (text, delay = 0.07, after = 0.4) => ({ op: "type", text, delay, after });

/** Carousel items that act on arrival: Map opens the outdoor recorder, Schedule pops its Streak challenge sheet. */
const PASS_OVER = new Set(["map", "schedule"]);

/**
 * Taps along the carousel from Home to a destination, one neighbour at a time. Map and Schedule are
 * jumped over (the carousel shows two neighbours each side) unless they are the destination.
 */
export function navigate(destination) {
  const home = NAVIGATION_ORDER.indexOf("home");
  const target = NAVIGATION_ORDER.indexOf(destination);
  if (target === -1) throw new Error(`Unknown destination ${destination}`);
  const step = target > home ? 1 : -1;
  const path = [];
  for (let index = home + step; step > 0 ? index <= target : index >= target; index += step) {
    const id = NAVIGATION_ORDER[index];
    if (index === target || !PASS_OVER.has(id)) path.push(id);
  }
  return path.map((id) => tap({ id: `navigation-item-${id}` }, 0.9));
}
