// Render a set of still frames after bundling once: node scripts/stills.mjs 10 40 70 ...
import {bundle} from "@remotion/bundler";
import {renderStill, selectComposition} from "@remotion/renderer";
import path from "node:path";
import fs from "node:fs";
import {fileURLToPath} from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const frames = process.argv.slice(2).map(Number);
const outDir = path.join(root, "out", "stills");
fs.mkdirSync(outDir, {recursive: true});
const serveUrl = await bundle({entryPoint: path.join(root, "src/index.ts")});
const comp = await selectComposition({serveUrl, id: "SoftNotesPromo"});
for (const frame of frames) {
  await renderStill({composition: comp, serveUrl, frame, output: path.join(outDir, `f${String(frame).padStart(3, "0")}.png`), scale: 0.5});
  console.log("frame", frame);
}
