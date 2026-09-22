/**
 * Round 3: exports C01-small (every level, dark/light), favicon tiles, the finalist lockups
 * (dark/light) and the D custom wordmarks. All wordmarks are outlined paths: no <text>, no fonts.
 * Run with: npm run export:svg:round3
 */
import fs from "node:fs";
import path from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { C01Small, FaviconTile } from "../src/round3/c01small";
import { LockupSvg, WordmarkSvg } from "../src/round3/lockup";
import { option, optionsOf } from "../src/round3/options";
import { FINALISTS } from "../src/round3/sheets";
import { darkPalette, lightPalette, type Palette } from "../src/tokens";

const OUT_DIR = path.resolve(__dirname, "..", "svg", "round3");
fs.mkdirSync(OUT_DIR, { recursive: true });

// The CSS background only shows when the file is opened directly; the artwork stays transparent.
const file = (markup: string, bg?: string) =>
  `<?xml version="1.0" encoding="UTF-8"?>\n${bg ? markup.replace(/^<svg /, `<svg style="background:${bg}" `) : markup}\n`;

const written: string[] = [];
const write = (name: string, markup: string, bg?: string) => {
  if (markup.includes("<text"))
    throw new Error(`${name} still contains <text>`);
  fs.writeFileSync(path.join(OUT_DIR, name), file(markup, bg), "utf8");
  written.push(name);
};

const variants: [string, Palette][] = [
  ["dark", darkPalette],
  ["light", lightPalette],
];

for (const [mode, p] of variants) {
  for (const level of [32, 24, 16] as const) {
    write(
      `c01-small-${level}-${mode}.svg`,
      renderToStaticMarkup(
        <C01Small size={level * 8} level={level} palette={p} />,
      ),
      p.bg,
    );
  }
  write(
    `favicon-${mode}.svg`,
    renderToStaticMarkup(
      <FaviconTile size={64} mode={mode as "dark" | "light"} />,
    ),
  );
}

for (const { id } of FINALISTS) {
  const o = option(id);
  for (const [mode, p] of variants) {
    write(
      `finalist-${id.toLowerCase()}-lockup-${mode}.svg`,
      renderToStaticMarkup(<LockupSvg opt={o} height={256} p={p} />),
      p.bg,
    );
  }
}

for (const o of optionsOf("D")) {
  for (const [mode, p] of variants) {
    write(
      `${o.id.toLowerCase()}-wordmark-${mode}.svg`,
      renderToStaticMarkup(<WordmarkSvg opt={o} fontSize={200} p={p} />),
      p.bg,
    );
    write(
      `${o.id.toLowerCase()}-lockup-${mode}.svg`,
      renderToStaticMarkup(<LockupSvg opt={o} height={256} p={p} />),
      p.bg,
    );
  }
}

console.log(`Wrote ${written.length} outlined SVG files to ${OUT_DIR}`);
