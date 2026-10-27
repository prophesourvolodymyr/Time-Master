#!/usr/bin/env node
// Re-encodes delivered clips from their raw masters with the stored trim: `node encode.mjs <clip-id ...>`.
import path from "node:path";
import { deliverClip, storedTrim, updateCatalog } from "./lib/catalog.mjs";
import { TOOLS_DIR } from "./lib/config.mjs";

const ids = process.argv.slice(2);
if (!ids.length) {
  await updateCatalog();
  process.stdout.write("Catalog regenerated.\n");
}
for (const id of ids) {
  const trim = await storedTrim(id);
  await deliverClip(id, { raw: path.join(TOOLS_DIR, trim.raw), start: trim.start, length: trim.length });
}
