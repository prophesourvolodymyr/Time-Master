import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const TOOLS_DIR = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
export const WEBSITE_DIR = path.resolve(TOOLS_DIR, "..", "..");
export const REPO_DIR = path.resolve(WEBSITE_DIR, "..");

export const SIMULATOR_NAME = "Tmax Web Recording";
export const BUNDLE_ID = "com.timemaster.TimeMaster";

export const DRIVER_PROJECT_DIR = path.join(TOOLS_DIR, "driver");
export const DRIVER_DIR = process.env.TMAX_DRIVER_DIR ?? "/tmp/tmax-driver";
export const DRIVER_DD = process.env.TMAX_DRIVER_DD ?? "/tmp/tmax-driver-dd";
export const APP_DD = process.env.TMAX_APP_DD ?? "/tmp/tmax-web-recording-dd";

export const RAW_DIR = path.join(TOOLS_DIR, "raw");
export const OUTPUT_DIR = path.join(WEBSITE_DIR, "public", "media", "app");
export const CATALOG_FILE = path.join(WEBSITE_DIR, "src", "content", "app-clips.ts");

function findSimulator(name) {
  const { devices } = JSON.parse(execFileSync("xcrun", ["simctl", "list", "devices", "-j"], { encoding: "utf8" }));
  const device = Object.values(devices).flat().find((candidate) => candidate.name === name && candidate.isAvailable);
  if (!device) throw new Error(`No simulator named "${name}". Create it first (node record.mjs --help).`);
  return device.udid;
}

export const UDID = process.env.TMAX_SIM_UDID ?? findSimulator(SIMULATOR_NAME);
