import { copyFile, mkdir, readFile, rm } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const destination = new URL("../templates/static/", import.meta.url);
const source = new URL("../../TimeMaster/Resources/", import.meta.url);
const icons = new URL("../../genesis/REFERENCE/lucide-icons/", import.meta.url);

await mkdir(destination, { recursive: true });
await Promise.all(["Inter-Regular.ttf", "TmaxRibbon-Regular.ttf"].map((name) =>
  rm(new URL(name, destination), { force: true })));
await Promise.all([
  ["Assets.xcassets/TmaxLogo.imageset/TmaxLogo.png", "tmax-logo.png"],
  ["Fonts/Manrope-Regular.ttf", "Manrope-Regular.ttf"],
  ["Fonts/Inter-Black.ttf", "Inter-Black.ttf"],
  ["Fonts/Inter-BlackItalic.ttf", "Inter-BlackItalic.ttf"],
  ["Fonts/TimeMaster-Regular.ttf", "TimeMaster-Regular.ttf"],
  ["Fonts/INTER-LICENSE.txt", "INTER-LICENSE.txt"],
  ["Fonts/MANROPE-LICENSE.txt", "MANROPE-LICENSE.txt"],
].map(([from, to]) => copyFile(new URL(from, source), new URL(to, destination))));
await copyFile(new URL("LICENSE", icons), new URL("LUCIDE-LICENSE.txt", destination));
await Promise.all(["dumbbell", "timer", "route", "arrow-up-right"].map(async (name) => {
  const svg = (await readFile(new URL(`${name}.svg`, icons), "utf8"))
    .replaceAll('stroke="currentColor"', 'stroke="#FFFFFF"');
  await sharp(Buffer.from(svg), { density: 288 })
    .resize(96, 96)
    .png()
    .toFile(fileURLToPath(new URL(`${name}.png`, destination)));
}));

console.log("Prepared original Tmax logo, current native fonts and licensed email-safe PNG icons.");
