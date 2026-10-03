// Renders the README mockup PNGs into ../docs/mockups.   node scripts/mockups.mjs
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const outDir = path.resolve(root, "../docs/mockups");
fs.mkdirSync(outDir, { recursive: true });
// name → logical frame of the promo timeline
const SHOTS = {
  "01-home": 26,
  "02-write": 69,
  "03-fold": 88,
  "04-filed": 121,
  "05-search": 152,
  "06-edit": 206,
};
const serveUrl = await bundle({ entryPoint: path.join(root, "src/index.ts") });
for (const [name, f] of Object.entries(SHOTS)) {
  const composition = await selectComposition({ serveUrl, id: "Mockup", inputProps: { f } });
  await renderStill({ composition, serveUrl, inputProps: { f }, frame: 0, scale: 0.75, output: path.join(outDir, `${name}.png`) });
  console.log(name);
}
