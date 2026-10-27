#!/usr/bin/env node
// Ad-hoc access to the XCUITest driver: `node drive.mjs start|stop|build` or `node drive.mjs '{"op":"dump"}'`.
import { buildDriver, ensureDriver, send, stopDriver } from "./lib/driver.mjs";

const [first, ...rest] = process.argv.slice(2);

if (first === "start") await ensureDriver();
else if (first === "stop") await stopDriver();
else if (first === "build") await buildDriver();
else if (first) {
  for (const json of [first, ...rest]) {
    const { value } = await send(JSON.parse(json));
    if (value !== null && value !== undefined) {
      process.stdout.write(typeof value === "string" ? `${value}\n` : `${JSON.stringify(value, null, 1)}\n`);
    }
  }
} else {
  process.stderr.write("usage: node drive.mjs start | stop | build | '<json command>'...\n");
  process.exitCode = 1;
}
