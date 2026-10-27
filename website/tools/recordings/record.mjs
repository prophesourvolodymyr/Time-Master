#!/usr/bin/env node
// Records the website's app clips: `node record.mjs [clip-id ...]`; `node record.mjs --help` prints setup and usage.
const args = process.argv.slice(2);

if (args.includes("--help") || args.includes("-h")) {
  const { help } = await import("./lib/help.mjs");
  process.stdout.write(help());
} else {
  const { recordScenes } = await import("./lib/record.mjs");
  await recordScenes(args);
}
