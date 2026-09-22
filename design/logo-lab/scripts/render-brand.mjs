/**
 * Renders the brand guide pages and raster brand assets with one bundle and ONE browser
 * (sequential, low memory). Usage:
 *   node scripts/render-brand.mjs            # everything
 *   node scripts/render-brand.mjs 07 08      # only pages BG-07 and BG-08
 *   node scripts/render-brand.mjs assets     # only the raster assets
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { bundle } from "@remotion/bundler";
import { getCompositions, openBrowser, renderStill } from "@remotion/renderer";

const here = path.dirname(fileURLToPath(import.meta.url));
const lab = path.resolve(here, "..");
const repo = path.resolve(lab, "..", "..");
const pagesDir = path.join(repo, "docs", "brand", "pages");
const assetsDir = path.join(repo, "assets", "brand");

const args = process.argv.slice(2);
const wantPage = (n) => args.length === 0 || args.includes(n);
const wantAssets = args.length === 0 || args.includes("assets");

const serveUrl = await bundle({
  entryPoint: path.join(lab, "src", "index.ts"),
  publicDir: path.join(lab, "public"),
});
const browser = await openBrowser("chrome", { chromiumOptions: {} });
const comps = await getCompositions(serveUrl, { puppeteerInstance: browser });

const jobs = [];
for (const c of comps) {
  const page = c.id.match(/^BG-(\d\d)-(.+)$/);
  if (page && wantPage(page[1]))
    jobs.push([c, path.join(pagesDir, `${page[1]}-${page[2]}.png`)]);
  const fav = c.id.match(/^BA-favicon-(\d+)$/);
  if (fav && wantAssets)
    jobs.push([c, path.join(assetsDir, "favicon", `favicon-${fav[1]}.png`)]);
  if (c.id === "BA-og-banner" && wantAssets)
    jobs.push([
      c,
      path.join(assetsDir, "social", "puls3-og-banner-1200x630.png"),
    ]);
  if (c.id === "BA-avatar" && wantAssets)
    jobs.push([c, path.join(assetsDir, "social", "puls3-avatar-800.png")]);
}

for (const [composition, output] of jobs) {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  await renderStill({
    composition,
    serveUrl,
    output,
    imageFormat: "png",
    puppeteerInstance: browser,
    overwrite: true,
  });
  console.log(`rendered ${composition.id} -> ${path.relative(repo, output)}`);
}
await browser.close({ silent: true });
