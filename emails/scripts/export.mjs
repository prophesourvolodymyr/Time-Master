import { cp, mkdir, mkdtemp, readdir, rename, rm, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { build } from "esbuild";
import { createElement } from "react";
import { render, toPlainText } from "react-email";

const root = fileURLToPath(new URL("../", import.meta.url));
const templates = join(root, "templates");
const out = join(root, "out");
const require = createRequire(import.meta.url);

async function templateFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    if (entry.name.startsWith("_") || entry.name === "static") return [];
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return templateFiles(path);
    return entry.name.endsWith(".tsx") ? [path] : [];
  }));
  return files.flat().sort();
}

await mkdir(out, { recursive: true });
const temporary = await mkdtemp(join(out, ".design-export-"));
const htmlDirectory = join(temporary, "html");
const textDirectory = join(temporary, "text");
await Promise.all([mkdir(htmlDirectory), mkdir(textDirectory)]);

try {
  const files = await templateFiles(templates);
  for (const file of files) {
    const name = relative(templates, file).replace(/\.tsx$/, "");
    const bundle = join(temporary, "bundles", `${name}.cjs`);
    await build({ entryPoints: [file], outfile: bundle, bundle: true, platform: "node",
      format: "cjs", target: "node22", packages: "external", logLevel: "silent" });
    const Template = require(bundle).default;
    if (typeof Template !== "function" || !Template.PreviewProps) {
      throw new Error(`${name} must export a React component with explicit PreviewProps for design export.`);
    }
    const html = await render(createElement(Template, Template.PreviewProps));
    const htmlPath = join(htmlDirectory, `${name}.html`);
    const textPath = join(textDirectory, `${name}.txt`);
    await Promise.all([mkdir(dirname(htmlPath), { recursive: true }), mkdir(dirname(textPath), { recursive: true })]);
    await Promise.all([writeFile(htmlPath, html), writeFile(textPath, toPlainText(html))]);
    console.log(`Exported ${name} (HTML + text)`);
  }
  await cp(join(templates, "static"), join(htmlDirectory, "static"), { recursive: true });
  await Promise.all([rm(join(out, "html"), { recursive: true, force: true }), rm(join(out, "text"), { recursive: true, force: true })]);
  await Promise.all([rename(htmlDirectory, join(out, "html")), rename(textDirectory, join(out, "text"))]);
  console.log(`Exported ${files.length} design previews. These use sample data, not live delivery inputs.`);
} finally {
  await rm(temporary, { recursive: true, force: true });
}
