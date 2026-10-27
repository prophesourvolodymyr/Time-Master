import { mkdir } from "node:fs/promises";
import path from "node:path";
import { SCENES, VANCOUVER } from "../scenes/index.mjs";
import { seed } from "../seed/seed.mjs";
import { deliverClip } from "./catalog.mjs";
import { RAW_DIR } from "./config.mjs";
import { ensureDriver, send } from "./driver.mjs";
import { motionBounds } from "./encode.mjs";
import { sleep } from "./process.mjs";
import { clearLocation, prepareDevice, setLocation, startRecording, stopRecording } from "./sim.mjs";

/** Fresh launch; the app holds its splash for at least five seconds before Home becomes interactive. */
async function launchToHome() {
  await send({ op: "launch" }, { timeout: 60_000 });
  await sleep(6_500);
  await send({ op: "wait", id: "home-canvas", timeout: 30 });
  await sleep(700);
}

async function recordScene(scene) {
  process.stdout.write(`\n▶ ${scene.id}\n`);
  await clearLocation();
  if (scene.seed !== false) await seed();
  await prepareDevice();
  await setLocation(scene.location ?? VANCOUVER);
  await ensureDriver();
  await send({ op: "quiescence", enabled: true });
  await launchToHome();
  if (scene.prepare?.length) await send({ op: "script", steps: scene.prepare }, { timeout: 600_000 });
  if (scene.beforeRecording) await scene.beforeRecording();
  await sleep((scene.settle ?? 1.2) * 1000);

  const raw = path.join(RAW_DIR, `${scene.id}.mov`);
  const recording = await startRecording(raw);
  await sleep(800);
  let script;
  try {
    script = await send({ op: "script", steps: scene.steps }, { timeout: 600_000 });
    await sleep((scene.hold ?? 1.2) * 1000);
  } finally {
    await stopRecording(recording);
    await send({ op: "quiescence", enabled: true }).catch(() => {});
    if (scene.afterRecording) await scene.afterRecording();
  }

  const timings = script.value;
  const firstStep = timings[0].started - recording.startedAt;
  const lastStep = timings[timings.length - 1].finished - recording.startedAt;
  const scriptEnd = script.finished - recording.startedAt;
  const motion = await motionBounds(raw);
  const bySteps = scene.trim === "steps";
  const fromSteps = bySteps || scene.from === "steps";
  const firstChange = !fromSteps && motion.firstMotion > 0.05 ? motion.firstMotion : firstStep;
  const start = Math.max(0, Math.min(firstChange, firstStep + 3) - (fromSteps ? 0 : scene.lead ?? 0.45));
  const settled = motion.lastMotion < motion.total - 0.05 ? Math.max(motion.lastMotion, lastStep - 0.2) : scriptEnd;
  const end = Math.min(motion.total, (bySteps ? scriptEnd : settled) + (scene.tail ?? 0.9));
  const duration = end - start;
  const limit = scene.maxDuration ?? 12.5;
  if (duration > limit + 0.01) {
    const steps = timings.map((step) => `${step.op} ${(step.finished - step.started).toFixed(1)}`).join(", ");
    process.stdout.write(`  ⚠ ${duration.toFixed(1)} s is longer than ${limit} s; tighten the scene pacing (${steps})\n`);
  }

  await deliverClip(scene.id, { raw, start, length: Math.min(duration, limit) });
}

/** Records the given scenes (every scene, in delivery order, when `ids` is empty). */
export async function recordScenes(ids) {
  const scenes = ids.length ? ids.map((id) => {
    const scene = SCENES.find((candidate) => candidate.id === id);
    if (!scene) throw new Error(`Unknown scene ${id}. Known: ${SCENES.map((candidate) => candidate.id).join(", ")}`);
    return scene;
  }) : SCENES;
  await mkdir(RAW_DIR, { recursive: true });
  for (const scene of scenes) await recordScene(scene);
  await clearLocation();
}
