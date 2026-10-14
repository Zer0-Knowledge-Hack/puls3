/**
 * Builds the downloadable brand kit served by the Flutter web app at /brand.
 *
 * - Copies every logo and mark SVG from assets/brand/ to puls3_flutter/web/brand/svg/.
 * - Rasterizes each SVG to transparent PNGs with the Chrome headless shell that Remotion
 *   already downloaded (node_modules/.remotion), so no extra native dependency is needed.
 * - Copies the guide PDF, tokens, favicons, social images and the Doto font (OFL).
 * - Writes manifest.json (one entry per variant) and a deterministic puls3-brand-kit.zip.
 *
 * Run with: npm run brand:kit
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import zlib from "node:zlib";
import { execFileSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const lab = path.resolve(here, "..");
const repo = path.resolve(lab, "..", "..");
const assets = path.join(repo, "assets", "brand");
const docs = path.join(repo, "docs", "brand");
const out = path.join(repo, "puls3_flutter", "web", "brand");
const zipName = "puls3-brand-kit.zip";

/** [id, label, background the file is drawn for, PNG widths in px]. */
const groups = {
  logo: [
    ["puls3-logo-dark", "Lockup, on dark", "dark", [1024, 2048]],
    ["puls3-logo-light", "Lockup, on light", "light", [1024, 2048]],
    ["puls3-logo-mono-white", "Lockup, mono white", "dark", [1024, 2048]],
    ["puls3-logo-mono-ink", "Lockup, mono ink", "light", [1024, 2048]],
    ["puls3-logo-dark-small", "Small lockup, on dark", "dark", [256, 512]],
    ["puls3-logo-light-small", "Small lockup, on light", "light", [256, 512]],
    ["puls3-logo-mono-white-small", "Small lockup, mono white", "dark", [256, 512]],
    ["puls3-logo-mono-ink-small", "Small lockup, mono ink", "light", [256, 512]],
  ],
  mark: [
    ["puls3-mark-c01-dark", "Mark, on dark", "dark", [512, 1024]],
    ["puls3-mark-c01-light", "Mark, on light", "light", [512, 1024]],
    ["puls3-mark-c01-mono-white", "Mark, mono white", "dark", [512, 1024]],
    ["puls3-mark-c01-mono-ink", "Mark, mono ink", "light", [512, 1024]],
    ...[32, 24, 16].flatMap((level) => [
      [`puls3-mark-c01-small-${level}-dark`, `Small mark ${level} px, on dark`, "dark", [level, level * 2]],
      [`puls3-mark-c01-small-${level}-light`, `Small mark ${level} px, on light`, "light", [level, level * 2]],
    ]),
  ],
};

function chromePath() {
  const root = path.join(lab, "node_modules", ".remotion", "chrome-headless-shell");
  const candidates = {
    win32: ["win64/chrome-headless-shell-win64/chrome-headless-shell.exe"],
    darwin: [
      "mac-arm64/chrome-headless-shell-mac-arm64/chrome-headless-shell",
      "mac-x64/chrome-headless-shell-mac-x64/chrome-headless-shell",
    ],
    linux: [
      "linux64/chrome-headless-shell-linux64/chrome-headless-shell",
      "linux-arm64/chrome-headless-shell-linux-arm64/chrome-headless-shell",
    ],
  }[process.platform] ?? [];
  const found = candidates.map((c) => path.join(root, c)).find(fs.existsSync);
  if (!found)
    throw new Error(
      "Chrome headless shell not found. Run `npm run brand:render` once so Remotion downloads it.",
    );
  return found;
}

/** Intrinsic size from the root <svg width height>. */
function svgSize(file) {
  const head = fs.readFileSync(file, "utf8").slice(0, 600);
  const m = head.match(/<svg[^>]*?\swidth="([\d.]+)"\s+height="([\d.]+)"/);
  if (!m) throw new Error(`No width/height on ${file}`);
  return { w: Number(m[1]), h: Number(m[2]) };
}

function rasterize(chrome, tmp, svg, width, png) {
  const { w, h } = svgSize(svg);
  const height = Math.round((width * h) / w);
  const html = path.join(tmp, "page.html");
  fs.writeFileSync(
    html,
    `<!doctype html><html><body style="margin:0;background:transparent">` +
      `<img src="${pathToFileURL(svg)}" style="display:block;width:${width}px;height:${height}px">` +
      `</body></html>`,
  );
  execFileSync(
    chrome,
    [
      "--headless",
      "--disable-gpu",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      "--default-background-color=00000000",
      `--window-size=${width},${height}`,
      `--screenshot=${png}`,
      pathToFileURL(html).href,
    ],
    { stdio: "pipe" },
  );
  if (!fs.existsSync(png)) throw new Error(`Chrome did not write ${png}`);
}

function copy(from, to) {
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
}

/** Minimal deterministic ZIP (deflate, fixed timestamps, sorted entries). */
function writeZip(file, entries) {
  const dosTime = 0; // 00:00:00
  const dosDate = ((2026 - 1980) << 9) | (1 << 5) | 1; // 2026-01-01
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const { name, data } of entries) {
    const nameBuf = Buffer.from(name, "utf8");
    const deflated = zlib.deflateRawSync(data, { level: 9 });
    const stored = deflated.length >= data.length;
    const body = stored ? data : deflated;
    const crc = zlib.crc32(data);
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6); // UTF-8 names
    local.writeUInt16LE(stored ? 0 : 8, 8);
    local.writeUInt16LE(dosTime, 10);
    local.writeUInt16LE(dosDate, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(body.length, 18);
    local.writeUInt32LE(data.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);
    central.writeUInt16LE(20, 6);
    central.writeUInt16LE(0x0800, 8);
    central.writeUInt16LE(stored ? 0 : 8, 10);
    central.writeUInt16LE(dosTime, 12);
    central.writeUInt16LE(dosDate, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(body.length, 20);
    central.writeUInt32LE(data.length, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt32LE(offset, 42);
    locals.push(local, nameBuf, body);
    centrals.push(central, nameBuf);
    offset += local.length + nameBuf.length + body.length;
  }
  const centralSize = centrals.reduce((n, b) => n + b.length, 0);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(entries.length, 8);
  end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(centralSize, 12);
  end.writeUInt32LE(offset, 16);
  fs.writeFileSync(file, Buffer.concat([...locals, ...centrals, end]));
}

function listFiles(dir, base = dir) {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((e) => {
      const full = path.join(dir, e.name);
      return e.isDirectory() ? listFiles(full, base) : [path.relative(base, full)];
    })
    .map((p) => p.split(path.sep).join("/"))
    .sort();
}

const chrome = chromePath();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "puls3-brand-kit-"));
fs.rmSync(out, { recursive: true, force: true });

const variants = [];
for (const [group, items] of Object.entries(groups)) {
  for (const [id, label, background, widths] of items) {
    const svgSrc = path.join(assets, group, `${id}.svg`);
    const svg = `svg/${group}/${id}.svg`;
    copy(svgSrc, path.join(out, svg));
    const png = [];
    for (const width of widths) {
      const rel = `png/${group}/${id}-${width}.png`;
      fs.mkdirSync(path.dirname(path.join(out, rel)), { recursive: true });
      rasterize(chrome, tmp, svgSrc, width, path.join(out, rel));
      png.push({ width, path: rel });
      console.log(`rendered ${rel}`);
    }
    variants.push({ id, group, label, background, svg, png });
  }
}
fs.rmSync(tmp, { recursive: true, force: true });

copy(path.join(docs, "puls3-brand-guide.pdf"), path.join(out, "puls3-brand-guide.pdf"));
copy(path.join(docs, "tokens.json"), path.join(out, "tokens.json"));
for (const f of fs.readdirSync(path.join(assets, "favicon")))
  copy(path.join(assets, "favicon", f), path.join(out, "favicon", f));
for (const f of fs.readdirSync(path.join(assets, "social")))
  copy(path.join(assets, "social", f), path.join(out, "social", f));
// Doto is SIL OFL 1.1: redistribution is allowed with the license alongside.
copy(path.join(assets, "fonts", "Doto[ROND,wght].ttf"), path.join(out, "fonts", "Doto[ROND,wght].ttf"));
copy(path.join(assets, "fonts", "OFL.txt"), path.join(out, "fonts", "OFL.txt"));

fs.writeFileSync(
  path.join(out, "manifest.json"),
  JSON.stringify({ name: "puls3 brand kit", zip: zipName, guide: "puls3-brand-guide.pdf", variants }, null, 2) + "\n",
);

const files = listFiles(out).filter((f) => f !== zipName);
writeZip(
  path.join(out, zipName),
  files.map((f) => ({ name: `puls3-brand-kit/${f}`, data: fs.readFileSync(path.join(out, f)) })),
);
const kb = (fs.statSync(path.join(out, zipName)).size / 1024).toFixed(0);
console.log(`wrote ${files.length} files + ${zipName} (${kb} KB) to ${path.relative(repo, out)}`);
