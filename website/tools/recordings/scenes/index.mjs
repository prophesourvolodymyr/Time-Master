// Scene scripts: `prepare` runs unrecorded after a fresh launch on Home; `steps` run while recording.
// Points are iPhone 17 Pro screen points (402 x 874). Clips start at the first visible motion minus `lead`;
// `from: "steps"` starts at the first step instead (its opening pause holds the first frame), and
// `trim: "steps"` also ends at the last step, for screens that never sit still.
import { drag, navigate, openDarkMap, pause, quiescence, runFor, tap, wait } from "./helpers.mjs";

export { VANCOUVER } from "./helpers.mjs";

const openWorkout = (name) => [
  ...navigate("workouts"),
  tap({ labelContains: name, type: "button" }, 1.4),
  wait({ label: "Start Workout", type: "button" }),
];

const startWithoutWarmUp = [
  tap({ label: "Start Workout", type: "button" }, 1.1),
  tap({ label: "No warm-up", type: "button" }, 0.5),
  tap({ label: "Start", type: "button" }, 0.4),
];

/** From the Exercise Database: opens the Push-Ups group page, then one of its exercise pages. */
const openExercise = (title) => [
  tap({ label: "Open Push-Ups", type: "button" }, 1.6),
  drag([201, 650], [201, 380], { velocity: 500, hold: 0.12, after: 1.0 }),
  tap({ labelContains: `${title}, Strength`, type: "button" }, 1.6),
  wait({ label: "Add to Workout", type: "button" }),
];

export const SCENES = [
  {
    id: "home",
    steps: [
      pause(0.5),
      drag([201, 600], [201, 250], { velocity: 520, after: 1.0 }),
      drag([201, 600], [201, 210], { velocity: 560, after: 1.0 }),
      drag([201, 600], [201, 210], { velocity: 560, after: 1.1 }),
    ],
  },
  {
    id: "workout-player",
    prepare: openWorkout("Push Day Ladder"),
    steps: [
      quiescence(false),
      pause(0.6),
      ...startWithoutWarmUp,
      pause(5.4),
    ],
    hold: 0.4,
    tail: 0.3,
  },
  {
    id: "timer",
    prepare: [
      ...openWorkout("Push Day Ladder"),
      quiescence(false),
      ...startWithoutWarmUp,
      tap({ label: "Skip Preparation", type: "button" }, 33),
    ],
    steps: [
      pause(3.6),
      tap({ label: "+15s", type: "button" }, 1.7),
      tap({ label: "Skip Rest", type: "button" }, 2.6),
    ],
    trim: "steps",
    hold: 0.4,
    tail: 0.2,
  },
  {
    id: "builder",
    prepare: [
      ...navigate("database"),
      ...openExercise("Close-Grip Push-Up"),
    ],
    steps: [
      pause(0.9),
      tap({ label: "Add to Workout", type: "button" }, 0.9),
      tap({ id: "plus", type: "button", index: 1 }, 0.5),
      tap({ id: "minus", type: "button", index: 2 }, 0.6),
      tap({ labelContains: "Push Day Ladder", type: "button" }, 0.6),
      tap({ id: "navigation-item-workouts" }, 0.8),
      tap({ labelContains: "Push Day Ladder", type: "button" }, 1.0),
      drag([201, 540], [201, 120], { velocity: 1600, hold: 0, after: 1.6 }),
    ],
    from: "steps",
  },
  {
    id: "database",
    prepare: navigate("database"),
    steps: [
      pause(0.8),
      tap({ label: "Expand Push-Ups", type: "button" }, 0.9),
      tap({ label: "Open Push-Ups", type: "button" }, 0.7),
      drag([201, 650], [201, 380], { velocity: 500, hold: 0.15, after: 0.6 }),
      tap({ labelContains: "Diamond Push-Up, Strength", type: "button" }, 1.2),
      drag([201, 640], [201, 330], { velocity: 450, hold: 0.15, after: 1.2 }),
    ],
    from: "steps",
  },
  {
    id: "map-recording",
    prepare: [...openDarkMap, tap({ label: "Start Run recording", type: "button" }, 1.5)],
    beforeRecording: runFor(80),
    steps: [pause(9.6)],
    trim: "steps",
    tail: 0.4,
  },
  {
    id: "routes",
    prepare: openDarkMap,
    steps: [
      pause(0.9),
      tap({ label: "Library", type: "button" }, 1.4),
      tap({ labelContains: "Stanley Park Seawall Loop", type: "button" }, 2.4),
      tap({ label: "Share or export workout", type: "button" }, 1.2),
      tap({ label: "FIT", type: "button" }, 0.7),
      tap({ label: "Prepare export", type: "button" }, 1.4),
    ],
    trim: "steps",
    tail: 0.3,
  },
];
