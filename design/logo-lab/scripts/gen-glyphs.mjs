/**
 * Generates outline data for the round-3 wordmark candidates.
 *
 * Downloads static TTF instances from the Google Fonts CSS API (one file per weight),
 * lays out "puls3" and "PULS3" with fontkit (kerning included), and writes SVG path data
 * (1000 units per em, y down, baseline at y = 0) to src/round3/generated/glyphs.ts.
 * Flattened contours are also written so the
 * wordmark can be re-sampled into halftone dots without a font at runtime.
 *
 * Run with: npm run gen:glyphs
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as fontkit from "fontkit";

const INSTANCES = [
  // Doto with its roundness axis at 100: round dots, like the C01 halftone.
  { key: "DotoRound500", family: "Doto", weight: 500, axes: "ROND,wght@100," },
  { key: "DotoRound900", family: "Doto", weight: 900, axes: "ROND,wght@100," },
  { key: "Unbounded700", family: "Unbounded", weight: 700 },
  { key: "Sora700", family: "Sora", weight: 700 },
  { key: "Sora600", family: "Sora", weight: 600 },
  { key: "Tektur500", family: "Tektur", weight: 500 },
  { key: "ZenDots400", family: "Zen Dots", weight: 400 },
  { key: "Audiowide400", family: "Audiowide", weight: 400 },
  { key: "Quantico700", family: "Quantico", weight: 700 },
  { key: "Electrolize400", family: "Electrolize", weight: 400 },
  { key: "Michroma400", family: "Michroma", weight: 400 },
  { key: "Unbounded200", family: "Unbounded", weight: 200 },
  { key: "Unbounded300", family: "Unbounded", weight: 300 },
  { key: "LexendGiga300", family: "Lexend Giga", weight: 300 },
  { key: "Syncopate400", family: "Syncopate", weight: 400 },
];

const STRINGS = ["puls3", "PULS3"];
const r1 = (n) => Math.round(n * 10) / 10;

const ttfUrl = async (family, weight, axes) => {
  const spec = axes ? `${axes}${weight}` : `wght@${weight}`;
  const q = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(family)}:${spec}`;
  // No browser user agent: the API answers with plain TTF files.
  const css = await (await fetch(q)).text();
  const m = css.match(/url\((https:[^)]+\.ttf)\)/);
  if (!m) throw new Error(`No TTF for ${family} ${weight}: ${css.slice(0, 200)}`);
  return m[1];
};

/** Converts fontkit path commands to y-down 1000-upm SVG path data and flattened contours. */
const convert = (glyph, s, dx) => {
  const P = (x, y) => [dx + x * s, -y * s];
  let d = "";
  const contours = [];
  let cur = null;
  let last = [0, 0];
  const push = (pt) => cur && cur.push([r1(pt[0]), r1(pt[1])]);
  for (const c of glyph.path.commands) {
    const a = c.args;
    if (c.command === "moveTo") {
      const p = P(a[0], a[1]);
      d += `M${r1(p[0])} ${r1(p[1])}`;
      cur = [];
      contours.push(cur);
      push(p);
      last = p;
    } else if (c.command === "lineTo") {
      const p = P(a[0], a[1]);
      d += `L${r1(p[0])} ${r1(p[1])}`;
      push(p);
      last = p;
    } else if (c.command === "quadraticCurveTo") {
      const q = P(a[0], a[1]);
      const p = P(a[2], a[3]);
      d += `Q${r1(q[0])} ${r1(q[1])} ${r1(p[0])} ${r1(p[1])}`;
      for (let i = 1; i <= 8; i++) {
        const t = i / 8;
        const u = 1 - t;
        push([u * u * last[0] + 2 * u * t * q[0] + t * t * p[0], u * u * last[1] + 2 * u * t * q[1] + t * t * p[1]]);
      }
      last = p;
    } else if (c.command === "bezierCurveTo") {
      const c1 = P(a[0], a[1]);
      const c2 = P(a[2], a[3]);
      const p = P(a[4], a[5]);
      d += `C${r1(c1[0])} ${r1(c1[1])} ${r1(c2[0])} ${r1(c2[1])} ${r1(p[0])} ${r1(p[1])}`;
      for (let i = 1; i <= 10; i++) {
        const t = i / 10;
        const u = 1 - t;
        push([
          u * u * u * last[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * p[0],
          u * u * u * last[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * p[1],
        ]);
      }
      last = p;
    } else if (c.command === "closePath") {
      d += "Z";
    }
  }
  return { d, contours };
};

const out = {};
for (const inst of INSTANCES) {
  const url = await ttfUrl(inst.family, inst.weight, inst.axes);
  const buf = Buffer.from(await (await fetch(url)).arrayBuffer());
  const font = fontkit.create(buf);
  const s = 1000 / font.unitsPerEm;
  const layouts = {};
  for (const str of STRINGS) {
    const run = font.layout(str);
    let x = 0;
    const glyphs = run.glyphs.map((g, i) => {
      const pos = run.positions[i];
      const { d, contours } = convert(g, s, x + pos.xOffset * s);
      const bb = g.bbox;
      const item = {
        char: str[i],
        x: r1(x),
        adv: r1(pos.xAdvance * s),
        d,
        bbox: [r1(x + bb.minX * s), r1(-bb.maxY * s), r1(x + bb.maxX * s), r1(-bb.minY * s)],
      };
      item.contours = contours;
      x += pos.xAdvance * s;
      return item;
    });
    layouts[str] = { width: r1(x), glyphs };
  }
  out[inst.key] = {
    family: inst.family,
    weight: inst.weight,
    ascender: r1(font.ascent * s),
    descender: r1(font.descent * s),
    capHeight: r1(font.capHeight * s),
    xHeight: r1(font.xHeight * s),
    layouts,
  };
  console.log(`${inst.key}: ${inst.family} ${inst.weight} (${url.split("/").pop()})`);
}

const here = path.dirname(fileURLToPath(import.meta.url));
const target = path.resolve(here, "..", "src", "round3", "generated", "glyphs.ts");
const body =
  "// GENERATED by scripts/gen-glyphs.mjs. Do not edit by hand.\n" +
  "import type { GlyphFont } from \"../outline\";\n\n" +
  `export const GLYPH_FONTS = ${JSON.stringify(out)} satisfies Record<string, GlyphFont>;\n`;
fs.writeFileSync(target, body, "utf8");
console.log(`Wrote ${target} (${(body.length / 1024).toFixed(0)} KB)`);
