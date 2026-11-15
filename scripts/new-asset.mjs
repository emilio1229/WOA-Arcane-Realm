import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";

const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => {
  if (!value.startsWith("--")) return pairs;
  pairs.push([value.slice(2), all[index + 1]?.startsWith("--") ? "" : all[index + 1] ?? ""]);
  return pairs;
}, []));
const required = ["id", "category", "name"];
for (const key of required) {
  if (!args[key]) throw new Error(`Missing required argument --${key}`);
}

const folders = {
  character: "characters",
  familiar: "familiars",
  creature: "creatures",
  environment: "environment",
  vfx: "vfx",
  ui: "ui",
  building: "buildings",
  prop: "props",
};
if (!folders[args.category]) throw new Error(`Unsupported category: ${args.category}`);
if (!/^[a-z0-9]+(?:[.-][a-z0-9]+)*$/.test(args.id)) throw new Error("Asset ID must use lowercase letters, numbers, dots, and hyphens.");
const width = Number(args.width ?? 256);
const height = Number(args.height ?? 256);
if (!Number.isInteger(width) || !Number.isInteger(height) || width < 16 || height < 16 || width > 4096 || height > 4096) {
  throw new Error("Width and height must be whole numbers between 16 and 4096.");
}
const tags = (args.tags ?? args.category).split(",").map(tag => tag.trim()).filter(Boolean);
const slug = args.id.split(".").slice(1).join("-") || args.id;
const relativePath = `/assets/${folders[args.category]}/${slug}.svg`;
const absolutePath = resolve("public", relativePath.slice(1));
const manifestPath = resolve("public/assets/manifest.json");
if (!existsSync(manifestPath)) throw new Error("Missing public/assets/manifest.json");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
if (manifest.assets.some(asset => asset.id === args.id)) throw new Error(`Asset ID already exists: ${args.id}`);
if (existsSync(absolutePath)) throw new Error(`Asset file already exists: ${relativePath}`);

const safeTitle = args.name.replace(/[&<>"]/g, char => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[char]);
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" fill="none">
  <title>${safeTitle}</title>
  <defs>
    <linearGradient id="primary" x1="0" y1="0" x2="1" y2="1">
      <stop stop-color="#f0d5ff"/>
      <stop offset="1" stop-color="#7950b8"/>
    </linearGradient>
  </defs>
  <!-- Replace this scaffold with original artwork; preserve the viewBox and transparent background. -->
  <circle cx="${width / 2}" cy="${height / 2}" r="${Math.min(width, height) * 0.34}" fill="url(#primary)" opacity=".22"/>
  <path d="M${width / 2} ${height * 0.18} L${width * 0.72} ${height * 0.78} L${width * 0.28} ${height * 0.78} Z" fill="url(#primary)" stroke="#f4e4ff" stroke-width="${Math.max(2, Math.min(width, height) * 0.018)}" opacity=".8"/>
</svg>
`;
const record = {
  id: args.id,
  path: relativePath,
  category: args.category,
  format: "svg",
  source: true,
  width,
  height,
  tags,
  status: "scaffold",
};
manifest.assets.push(record);
writeFileSync(absolutePath, svg, { flag: "wx" });
try {
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + "\n");
} catch (error) {
  throw new Error(`Asset source created at ${relativePath}, but manifest update failed: ${error.message}`);
}
console.log(`Created ${args.id} at ${relativePath}. Replace the scaffold art, then run npm run assets:validate.`);
