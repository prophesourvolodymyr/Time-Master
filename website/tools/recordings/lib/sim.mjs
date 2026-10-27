import { spawn } from "node:child_process";
import { once } from "node:events";
import { stat } from "node:fs/promises";
import { BUNDLE_ID, UDID } from "./config.mjs";
import { run, sleep } from "./process.mjs";

const simctl = (...args) => run("xcrun", ["simctl", ...args]);

export async function appContainer() {
  const { stdout } = await simctl("get_app_container", UDID, BUNDLE_ID, "data");
  return stdout.trim();
}

export async function terminateApp() {
  await simctl("terminate", UDID, BUNDLE_ID).catch(() => {});
}

export async function launchApp() {
  await simctl("launch", UDID, BUNDLE_ID);
}

/** Dark appearance and the classic 9:41 showcase status bar. */
export async function prepareDevice() {
  await simctl("ui", UDID, "appearance", "dark");
  await simctl(
    "status_bar", UDID, "override",
    "--time", "9:41",
    "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
    "--cellularMode", "active", "--cellularBars", "4", "--operatorName", "",
    "--batteryState", "discharging", "--batteryLevel", "100",
  );
}

export async function grantPrivacy() {
  for (const service of ["location", "motion", "photos"]) {
    await simctl("privacy", UDID, "grant", service, BUNDLE_ID).catch(() => {});
  }
}

export async function setLocation([latitude, longitude]) {
  await simctl("location", UDID, "set", `${latitude},${longitude}`);
}

/** Moves the simulated position along waypoints at `speed` m/s with one update per second. */
export async function startLocationRoute(waypoints, speed) {
  const input = waypoints.map(([latitude, longitude]) => `${latitude},${longitude}`).join("\n");
  await run("xcrun", ["simctl", "location", UDID, "start", `--speed=${speed}`, "--interval=1", "-"], { input: `${input}\n` });
}

export async function clearLocation() {
  await simctl("location", UDID, "clear").catch(() => {});
}

export async function screenshot(file) {
  await simctl("io", UDID, "screenshot", "--type=png", file);
}

/** Starts `simctl io recordVideo` and resolves once the first frame is captured. */
export async function startRecording(file) {
  const child = spawn("xcrun", ["simctl", "io", UDID, "recordVideo", "--codec=h264", "--mask=ignored", "--force", file], {
    stdio: ["ignore", "ignore", "pipe"],
  });
  let log = "";
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`recordVideo did not start: ${log}`)), 20_000);
    child.stderr.on("data", (chunk) => {
      log += chunk;
      if (log.includes("Recording started")) {
        clearTimeout(timer);
        resolve();
      }
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      reject(new Error(`recordVideo exited with ${code}: ${log}`));
    });
  });
  return { child, file, startedAt: Date.now() / 1000 };
}

/** Stops with SIGINT (the documented way) and waits until the movie is finalized. */
export async function stopRecording({ child, file }) {
  const closed = once(child, "close");
  child.kill("SIGINT");
  await closed;
  await sleep(300);
  const { size } = await stat(file);
  if (size < 10_000) throw new Error(`Recording ${file} is empty (${size} bytes); reboot the simulator and retry.`);
}
