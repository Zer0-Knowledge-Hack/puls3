/**
 * Merges the rendered guide pages (docs/brand/pages/NN-*.png) into docs/brand/puls3-brand-guide.pdf.
 * Pages are embedded as JPEG (quality 90) to keep the PDF small; the PNGs stay as the source of truth.
 * Run with: npm run brand:pdf
 */
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { PDFDocument } from "pdf-lib";

const here = path.dirname(fileURLToPath(import.meta.url));
const lab = path.resolve(here, "..");
const docs = path.resolve(lab, "..", "..", "docs", "brand");
const pagesDir = path.join(docs, "pages");
const tmp = fs.mkdtempSync(path.join(lab, "out", "pdf-"));

const pages = fs
  .readdirSync(pagesDir)
  .filter((f) => /^\d\d-.+\.png$/.test(f))
  .sort();
if (pages.length !== 16)
  throw new Error(`Expected 16 pages, found ${pages.length}`);

const pdf = await PDFDocument.create();
pdf.setTitle("puls3 · Brand Guidelines 2026");
pdf.setAuthor("puls3");
pdf.setSubject("Brand guidelines: logo, color, typography, usage");
for (const file of pages) {
  const jpg = path.join(tmp, file.replace(/\.png$/, ".jpg"));
  // Remotion ships ffmpeg; use it to transcode PNG -> JPEG.
  execSync(
    `npx remotion ffmpeg -v error -y -i "${path.join(pagesDir, file)}" -q:v 2 "${jpg}"`,
    { cwd: lab },
  );
  const img = await pdf.embedJpg(fs.readFileSync(jpg));
  const page = pdf.addPage([960, 540]); // 16:9 landscape, points
  page.drawImage(img, { x: 0, y: 0, width: 960, height: 540 });
}
const out = path.join(docs, "puls3-brand-guide.pdf");
fs.writeFileSync(out, await pdf.save());
fs.rmSync(tmp, { recursive: true, force: true });
console.log(
  `Wrote ${out} · ${pages.length} pages · ${(fs.statSync(out).size / 1024 / 1024).toFixed(2)} MB`,
);
