import { LIVE_RUN, NAVIGATION_ORDER } from "../seed/demo.mjs";
import { sleep } from "../lib/process.mjs";

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

/**
 * The outdoor map in its Dark style with the camera following the current location. The map never
 * settles, so quiescence stays off for the rest of the scene.
 */
export const openDarkMap = [
  quiescence(false),
  ...navigate("map"),
  tap({ label: "Open map quick pane", type: "button" }, 1.0),
  tap({ label: "Map mode, Dark", type: "button" }, 0.8),
  tap({ label: "Close Map quick pane", type: "button" }, 1.2),
  tap({ label: "Focus current location", type: "button" }, 2.5),
];

/** Runs the simulated runner along the live route at a 3:42 /km pace for `seconds` before recording. */
export const runFor = (seconds) => async () => {
  const { startLocationRoute } = await import("../lib/sim.mjs");
  await startLocationRoute(LIVE_RUN, 4.5);
  await sleep(seconds * 1000);
};
