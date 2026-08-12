import fs from "fs";
import path from "path";
const { default: sharp } = await import(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES + "/sharp/lib/index.js");

const assets = "docs/chrome-web-store/assets";
const jobs = [
  ["promo-440x280", 440, 280],
  ["screenshot-popup-1280x800", 1280, 800],
  ["screenshot-downloads-1280x800", 1280, 800]
];

for (const [name, width, height] of jobs) {
  const svgPath = path.join(assets, `${name}.svg`);
  let svg = fs.readFileSync(svgPath, "utf8");
  svg = svg.replace(/href="([^"]+\.png)"/g, (_, relativePath) => {
    const imagePath = path.resolve(path.dirname(svgPath), relativePath);
    const base64 = fs.readFileSync(imagePath).toString("base64");
    return `href="data:image/png;base64,${base64}"`;
  });
  await sharp(Buffer.from(svg)).resize(width, height).png().toFile(path.join(assets, `${name}.png`));
}
