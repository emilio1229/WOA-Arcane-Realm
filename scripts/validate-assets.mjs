import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const manifestPath = resolve("public/assets/manifest.json");
if (!existsSync(manifestPath)) throw new Error("Missing public/assets/manifest.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
if (!Array.isArray(manifest.assets) || manifest.assets.length === 0) throw new Error("Asset manifest must contain assets");

const ids = new Set();
const failures = [];
for (const asset of manifest.assets) {
  if (!asset.id || ids.has(asset.id)) failures.push(`Missing or duplicate asset ID: ${asset.id ?? "(empty)"}`);
  ids.add(asset.id);
  if (!asset.path?.startsWith("/assets/")) failures.push(`Invalid public asset path for ${asset.id}`);
  const filePath = resolve("public", asset.path?.replace(/^\//, "") ?? "");
  if (!existsSync(filePath)) { failures.push(`Missing file: ${asset.path}`); continue; }
  const source = readFileSync(filePath, "utf8");
  if (!source.includes("<svg") || !source.includes("</svg>")) failures.push(`Not a complete SVG document: ${asset.path}`);
  const root = source.match(/<svg\b([^>]*)>/);
  if (!root) { failures.push(`Missing SVG root: ${asset.path}`); continue; }
  const width = Number(root[1].match(/\bwidth="(\d+)"/)?.[1]);
  const height = Number(root[1].match(/\bheight="(\d+)"/)?.[1]);
  if (width !== asset.width || height !== asset.height) failures.push(`Manifest dimensions mismatch: ${asset.path} (manifest ${asset.width}x${asset.height}, SVG ${width}x${height})`);
  if (/<script\b|javascript:|https?:\/\//i.test(source)) failures.push(`External/script content is not allowed in game SVG: ${asset.path}`);
}
if (failures.length) {
  console.error("Asset validation failed:");
  for (const failure of failures) console.error(` - ${failure}`);
  process.exitCode = 1;
} else {
  console.log(`Validated ${manifest.assets.length} assets: unique IDs, files, SVG roots, dimensions, and safe inline-only content.`);
}
