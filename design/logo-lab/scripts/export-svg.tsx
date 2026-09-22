/**
 * Exports every concept's static mark and lockup as standalone SVG files into ./svg.
 * Run with: npm run export:svg
 *
 * The components are pure SVG, so they render with react-dom/server outside Remotion.
 * Wordmarks stay as <text>; a Google Fonts @import is embedded so the files render
 * with the brand fonts when opened in a browser (fallback fonts otherwise).
 */
import fs from "node:fs";
import path from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { CONCEPTS } from "../src/concepts";
import { darkPalette, lightPalette, type Palette } from "../src/tokens";

const OUT_DIR = path.resolve(__dirname, "..", "svg");

const FONT_STYLE =
  "<defs><style>@import url('https://fonts.googleapis.com/css2?family=Instrument+Serif&amp;family=Manrope:wght@800&amp;display=swap');</style></defs>";

// The CSS background only shows when the file is opened directly (e.g. in a browser);
// design tools ignore it, so the artwork itself stays transparent.
const toFile = (markup: string, withFonts: boolean, palette: Palette) => {
  const withBg = markup.replace(
    /^<svg /,
    `<svg style="background:${palette.bg}" `,
  );
  const body = withFonts
    ? withBg.replace(/^(<svg[^>]*>)/, `$1${FONT_STYLE}`)
    : withBg;
  return `<?xml version="1.0" encoding="UTF-8"?>\n${body}\n`;
};

const kebab = (s: string) =>
  s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

fs.mkdirSync(OUT_DIR, { recursive: true });

const written: string[] = [];
const variants: [string, Palette][] = [
  ["", darkPalette],
  ["-light", lightPalette],
];

for (const c of CONCEPTS) {
  const base = `${c.code.toLowerCase()}-${kebab(c.slug)}`;
  const files: [string, string][] = [];
  for (const [suffix, palette] of variants) {
    const mark = renderToStaticMarkup(<c.Mark size={512} palette={palette} />);
    const lockup = renderToStaticMarkup(
      <c.Lockup height={320} palette={palette} />,
    );
    files.push([
      `${base}-mark${suffix}.svg`,
      toFile(mark, mark.includes("<text"), palette),
    ]);
    files.push([`${base}-lockup${suffix}.svg`, toFile(lockup, true, palette)]);
  }
  for (const [name, content] of files) {
    fs.writeFileSync(path.join(OUT_DIR, name), content, "utf8");
    written.push(name);
  }
}

console.log(`Wrote ${written.length} SVG files to ${OUT_DIR}`);
for (const f of written) console.log(`  ${f}`);
