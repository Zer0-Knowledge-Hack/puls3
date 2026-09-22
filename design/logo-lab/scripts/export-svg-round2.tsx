/**
 * Round 2: exports every R mark (full + small variant) and lockup as standalone SVGs
 * into ./svg/round2, plus the 3 x 3 lockup picks.
 * Run with: npm run export:svg:round2
 */
import fs from "node:fs";
import path from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import { makeRLockup, rConcept, R_CONCEPTS } from "../src/round2/concepts";
import { PICK_FONTS, PICK_MARKS } from "../src/round2/sheets";
import { darkPalette, lightPalette, type Palette } from "../src/tokens";

const OUT_DIR = path.resolve(__dirname, "..", "svg", "round2");

const FONT_STYLE =
  "<defs><style>@import url('https://fonts.googleapis.com/css2?family=Unbounded:wght@500&amp;family=Michroma&amp;family=Sora:wght@600&amp;display=swap');</style></defs>";

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
const write = (name: string, content: string) => {
  fs.writeFileSync(path.join(OUT_DIR, name), content, "utf8");
  written.push(name);
};

const variants: [string, Palette][] = [
  ["", darkPalette],
  ["-light", lightPalette],
];

for (const c of R_CONCEPTS) {
  const base = `${c.code.toLowerCase()}-${kebab(c.slug)}`;
  for (const [suffix, palette] of variants) {
    write(
      `${base}-mark${suffix}.svg`,
      toFile(
        renderToStaticMarkup(
          <c.RMark size={512} palette={palette} variant="full" />,
        ),
        false,
        palette,
      ),
    );
    if (c.SmallArt) {
      write(
        `${base}-mark-small${suffix}.svg`,
        toFile(
          renderToStaticMarkup(
            <c.RMark size={64} palette={palette} variant="small" />,
          ),
          false,
          palette,
        ),
      );
    }
    write(
      `${base}-lockup${suffix}.svg`,
      toFile(
        renderToStaticMarkup(<c.Lockup height={320} palette={palette} />),
        true,
        palette,
      ),
    );
  }
}

for (const code of PICK_MARKS) {
  const c = rConcept(code);
  for (const font of PICK_FONTS) {
    const L = makeRLockup(c.Art, c.name, font, 1);
    write(
      `pick-${code.toLowerCase()}-${kebab(font)}-lockup.svg`,
      toFile(
        renderToStaticMarkup(<L height={320} palette={darkPalette} />),
        true,
        darkPalette,
      ),
    );
  }
}

console.log(`Wrote ${written.length} SVG files to ${OUT_DIR}`);
