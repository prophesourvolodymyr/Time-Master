import { copyFile, mkdir } from "node:fs/promises";

const destination = new URL("../templates/static/", import.meta.url);
const source = new URL("../../TimeMaster/Resources/", import.meta.url);

await mkdir(destination, { recursive: true });
await Promise.all([
  ["Assets.xcassets/TmaxLogo.imageset/TmaxLogo.png", "tmax-logo.png"],
  ["Fonts/Inter-Regular.ttf", "Inter-Regular.ttf"],
  ["Fonts/Inter-Black.ttf", "Inter-Black.ttf"],
  ["Fonts/TmaxRibbon-Regular.ttf", "TmaxRibbon-Regular.ttf"],
  ["Fonts/INTER-LICENSE.txt", "INTER-LICENSE.txt"],
].map(([from, to]) => copyFile(new URL(from, source), new URL(to, destination))));

console.log("Prepared the app's original Tmax logo, Inter and Tmax Ribbon fonts, and Inter license for local previews.");
