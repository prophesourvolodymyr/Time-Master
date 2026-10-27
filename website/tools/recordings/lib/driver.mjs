import { spawn } from "node:child_process";
import { existsSync, openSync } from "node:fs";
import { copyFile, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { DRIVER_DD, DRIVER_DIR, DRIVER_PROJECT_DIR, UDID } from "./config.mjs";
import { run, sleep } from "./process.mjs";

let sequence = 0;

function nextName() {
  sequence += 1;
  return `${Date.now()}-${String(process.pid).padStart(6, "0")}-${String(sequence).padStart(6, "0")}.json`;
}

/** Sends one command to the XCUITest driver and resolves with its response. */
export async function send(command, { timeout = 180_000 } = {}) {
  const name = nextName();
  const inbox = path.join(DRIVER_DIR, "inbox");
  const answer = path.join(DRIVER_DIR, "outbox", name);
  await mkdir(inbox, { recursive: true });
  const temporary = path.join(inbox, `.${name}`);
  await writeFile(temporary, JSON.stringify(command));
  await rename(temporary, path.join(inbox, name));
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (existsSync(answer)) {
      const response = JSON.parse(await readFile(answer, "utf8"));
      await rm(answer, { force: true });
      if (!response.ok) throw new Error(`Driver ${command.op}: ${response.error}`);
      return response;
    }
    await sleep(10);
  }
  throw new Error(`Driver did not answer ${command.op} within ${timeout} ms`);
}

export async function isDriverRunning() {
  if (!existsSync(path.join(DRIVER_DIR, "ready"))) return false;
  try {
    await send({ op: "ping" }, { timeout: 4_000 });
    return true;
  } catch {
    return false;
  }
}

const PRODUCTS_DIR = path.join(DRIVER_DD, "Build", "Products");
const QUIET_XCTESTRUN = path.join(PRODUCTS_DIR, "recording.xctestrun");

async function builtXctestrun() {
  const files = existsSync(PRODUCTS_DIR) ? await readdir(PRODUCTS_DIR) : [];
  const file = files.find((name) => name.endsWith(".xctestrun") && name !== path.basename(QUIET_XCTESTRUN));
  return file ? path.join(PRODUCTS_DIR, file) : undefined;
}

export async function buildDriver() {
  await run("xcodegen", ["generate", "--quiet"], { cwd: DRIVER_PROJECT_DIR });
  await run(
    "xcodebuild",
    [
      "build-for-testing",
      "-project", "TmaxDriver.xcodeproj",
      "-scheme", "TmaxDriver",
      "-destination", `id=${UDID}`,
      "-derivedDataPath", DRIVER_DD,
      "-quiet",
    ],
    { cwd: DRIVER_PROJECT_DIR },
  );
}

/**
 * Copies the built .xctestrun with automatic screen capture switched off: the driver test runs for
 * hours, and XCTest's default screen recording of a UI test would otherwise grow without bound.
 */
async function quietXctestrun() {
  let built = await builtXctestrun();
  if (!built) {
    await buildDriver();
    built = await builtXctestrun();
  }
  await copyFile(built, QUIET_XCTESTRUN);
  for (const key of ["SystemAttachmentLifetime", "UserAttachmentLifetime"]) {
    await run("plutil", ["-replace", `TmaxDriverUITests.${key}`, "-string", "keepNever", QUIET_XCTESTRUN]);
  }
  await run("plutil", ["-remove", "TmaxDriverUITests.PreferredScreenCaptureFormat", QUIET_XCTESTRUN]).catch(() => {});
  return QUIET_XCTESTRUN;
}

/** Starts the long-running driver test (detached) unless one already answers. */
export async function ensureDriver() {
  if (await isDriverRunning()) return;
  await rm(DRIVER_DIR, { recursive: true, force: true });
  await mkdir(DRIVER_DIR, { recursive: true });
  const xctestrun = await quietXctestrun();
  const log = openSync(path.join(DRIVER_DIR, "xcodebuild.log"), "a");
  const child = spawn(
    "xcodebuild",
    [
      "test-without-building",
      "-xctestrun", xctestrun,
      "-destination", `id=${UDID}`,
      "-derivedDataPath", DRIVER_DD,
      "-resultBundlePath", path.join(DRIVER_DIR, "result.xcresult"),
      "-only-testing:TmaxDriverUITests/DriverTests/testServe",
    ],
    { detached: true, stdio: ["ignore", log, log], env: { ...process.env, TEST_RUNNER_TMAX_DRIVER_DIR: DRIVER_DIR } },
  );
  child.unref();
  const deadline = Date.now() + 240_000;
  while (Date.now() < deadline) {
    if (await isDriverRunning()) return;
    await sleep(500);
  }
  throw new Error(`Driver did not start; see ${path.join(DRIVER_DIR, "xcodebuild.log")}`);
}

export async function stopDriver() {
  if (await isDriverRunning()) await send({ op: "stop" }, { timeout: 10_000 });
}
