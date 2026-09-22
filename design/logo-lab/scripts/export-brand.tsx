/**
 * Brand guide 2026: exports the official vector assets to <repo>/assets/brand, writes
 * <repo>/docs/brand/tokens.json and prints the contrast report for every color pair in the guide.
 * All SVGs are outlined geometry (no <text>, no font dependency).
 * Run with: npm run brand:export
 */
import fs from "node:fs";
import path from "node:path";
import { renderToStaticMarkup } from "react-dom/server";
import {
  brandDark,
  brandLight,
  colors,
  monoInk,
  monoWhite,
  type Palette,
} from "../src/tokens";
import { contrast } from "../src/brand/contrast";
import {
  BrandLogo,
  BrandMark,
  LOCKUP_HALFTONE_MIN_MARK_PX,
  MARK_FULL_MIN_PX,
  THREE_HALFTONE_MIN_PX,
  WORDMARK_HALFTONE_MIN_PX,
  dotPitchForThree,
} from "../src/brand/logo";
import { C01Small, FaviconTile } from "../src/round3/c01small";
import { radius, spacing, typeScale } from "../src/brand/scale";

const repo = path.resolve(__dirname, "..", "..", "..");
const assets = path.join(repo, "assets", "brand");
const docs = path.join(repo, "docs", "brand");

const svgFile = (markup: string) => {
  if (markup.includes("<text")) throw new Error("SVG contains live text");
  return `<?xml version="1.0" encoding="UTF-8"?>\n${markup}\n`;
};
const written: string[] = [];
const write = (rel: string, markup: string) => {
  const out = path.join(assets, rel);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, svgFile(markup), "utf8");
  written.push(rel);
};

/* ------------------------------- Logos ------------------------------- */

const LOGO_VARIANTS: [string, Palette][] = [
  ["dark", brandDark],
  ["light", brandLight],
  ["mono-white", monoWhite],
  ["mono-ink", monoInk],
];

for (const [name, p] of LOGO_VARIANTS) {
  // Large: C01 full + halftone 3. Small: C01-small (32 level) + solid 3, for sizes below the threshold.
  write(
    `logo/puls3-logo-${name}.svg`,
    renderToStaticMarkup(
      <BrandLogo height={256} palette={p} three="halftone" mark="full" />,
    ),
  );
  write(
    `logo/puls3-logo-${name}-small.svg`,
    renderToStaticMarkup(
      <BrandLogo height={32} palette={p} three="solid" mark="small" />,
    ),
  );
}

/* ------------------------------- Marks ------------------------------- */

for (const [name, p] of [
  ["dark", brandDark],
  ["light", brandLight],
] as const) {
  write(
    `mark/puls3-mark-c01-${name}.svg`,
    renderToStaticMarkup(<BrandMark size={512} palette={p} mode="full" />),
  );
  for (const level of [32, 24, 16] as const) {
    write(
      `mark/puls3-mark-c01-small-${level}-${name}.svg`,
      renderToStaticMarkup(<C01Small size={level} level={level} palette={p} />),
    );
  }
}

write(
  "favicon/favicon.svg",
  renderToStaticMarkup(<FaviconTile size={32} mode="dark" />),
);
write(
  "favicon/favicon-light.svg",
  renderToStaticMarkup(<FaviconTile size={32} mode="light" />),
);

/* ------------------------------- Tokens ------------------------------ */

const tok = (value: string, role: string) => ({ value, role });
const dark = {
  background: tok(colors.background, "Page background"),
  surface: tok(colors.surface, "Cards, bars, panels"),
  text: tok(colors.text, "Primary text, wordmark"),
  muted: tok(colors.muted, "Secondary text"),
  accent: tok(colors.accent, "Pulse core, the 3, key actions"),
  lavender: tok(colors.lavender, "Pulse edge, secondary accents"),
  success: tok(colors.success, "Positive states"),
  hairline: tok(colors.hairline, "Dividers and borders (decorative)"),
};
const light = {
  paper: tok(colors.paper, "Light background"),
  white: tok(colors.white, "Cards on light"),
  ink: tok(colors.ink, "Primary text, wordmark"),
  mutedOnLight: tok(colors.mutedOnLight, "Secondary text on light"),
  accentOnLight: tok(
    colors.accentOnLight,
    "Solid 3, pulse core, actions on light",
  ),
  lavenderOnLight: tok(
    colors.lavenderOnLight,
    "Pulse edge, secondary accents on light",
  ),
  hairlineLight: tok(
    colors.hairlineLight,
    "Dividers and borders on light (decorative)",
  ),
};

type Pair = { fg: string; bg: string; use: "text" | "graphic"; min: number };
const PAIRS: Pair[] = [
  ...(["text", "muted", "accent", "lavender", "success"] as const).flatMap(
    (k) =>
      (["background", "surface"] as const).map((b) => ({
        fg: k,
        bg: b,
        use: "text" as const,
        min: 4.5,
      })),
  ),
  ...(
    ["ink", "mutedOnLight", "accentOnLight", "lavenderOnLight"] as const
  ).flatMap((k) =>
    (["paper", "white"] as const).map((b) => ({
      fg: k,
      bg: b,
      use: "text" as const,
      min: 4.5,
    })),
  ),
  { fg: "accentOnLight", bg: "paper", use: "graphic", min: 3 },
  { fg: "lavenderOnLight", bg: "paper", use: "graphic", min: 3 },
  { fg: "ink", bg: "accent", use: "text", min: 4.5 }, // dark button label
  { fg: "white", bg: "accentOnLight", use: "text", min: 4.5 }, // light button label
];
const all: Record<string, string> = Object.fromEntries(
  [...Object.entries(dark), ...Object.entries(light)].map(([k, v]) => [
    k,
    v.value,
  ]),
);
const report = PAIRS.map((p) => {
  const ratio = contrast(all[p.fg], all[p.bg]);
  return { ...p, ratio: Number(ratio.toFixed(2)), pass: ratio >= p.min };
});
// Reference only: why the on-light variants exist.
const reference = [
  {
    fg: "accent",
    bg: "paper",
    ratio: Number(contrast(colors.accent, colors.paper).toFixed(2)),
    note: "fails, do not use",
  },
  {
    fg: "lavender",
    bg: "paper",
    ratio: Number(contrast(colors.lavender, colors.paper).toFixed(2)),
    note: "fails, do not use",
  },
];

const tokens = {
  name: "puls3 brand tokens",
  version: "1.0.0",
  source: "docs/brand/puls3-brand-guide.pdf",
  color: {
    dark,
    light,
    mono: {
      white: tok(colors.text, "Mono logo on dark"),
      ink: tok(colors.ink, "Mono logo on light"),
    },
  },
  contrast: {
    wcag: "2.x",
    thresholds: { text: 4.5, graphic: 3 },
    pairs: report,
    reference,
  },
  typography: {
    families: {
      display: {
        family: "Unbounded",
        weights: [500, 700],
        use: "Display, headlines, the wordmark (700)",
      },
      accent: {
        family: "Doto",
        weights: [900],
        axes: { ROND: 100 },
        use: "Big numbers, stats, loading and status labels, event graphics. Never the logo, never body text.",
        source: "assets/brand/fonts/Doto[ROND,wght].ttf (self-hosted)",
      },
      ui: {
        family: "Manrope",
        weights: [400, 500, 600, 700, 800],
        use: "UI and body text",
      },
      data: {
        family: "JetBrains Mono",
        weights: [400, 500],
        use: "Addresses, tx hashes, code",
      },
    },
    scale: typeScale,
  },
  spacing,
  radius,
  logo: {
    threeHalftoneMinPx: THREE_HALFTONE_MIN_PX,
    threeHalftoneDotPitchPx: Number(
      dotPitchForThree(THREE_HALFTONE_MIN_PX).toFixed(2),
    ),
    lockupHalftoneMinMarkPx: LOCKUP_HALFTONE_MIN_MARK_PX,
    wordmarkHalftoneMinHeightPx: WORDMARK_HALFTONE_MIN_PX,
    markFullMinPx: MARK_FULL_MIN_PX,
    markSmallLevels: [32, 24, 16],
    clearSpace: {
      unit: "c = diameter of the C01 center dot = 0.072 x mark height",
      value: "4c",
    },
    minimum: {
      lockupMarkPx: 24,
      markPx: 16,
      wordmarkHeightPx: 14,
      print: { lockupMm: 25, markMm: 6, wordmarkMm: 18 },
    },
  },
};
fs.mkdirSync(docs, { recursive: true });
fs.writeFileSync(
  path.join(docs, "tokens.json"),
  `${JSON.stringify(tokens, null, 2)}\n`,
  "utf8",
);

console.log(
  `Wrote ${written.length} SVGs to assets/brand and docs/brand/tokens.json\n`,
);
console.log("Contrast report (WCAG 2.x):");
for (const r of report) {
  console.log(
    `  ${r.pass ? "PASS" : "FAIL"}  ${r.fg.padEnd(16)} on ${r.bg.padEnd(14)} ${r.ratio.toFixed(2).padStart(6)}:1  (${r.use} >= ${r.min})`,
  );
}
for (const r of reference)
  console.log(
    `  REF   ${r.fg.padEnd(16)} on ${r.bg.padEnd(14)} ${r.ratio.toFixed(2).padStart(6)}:1  (${r.note})`,
  );
console.log(
  `\nHalftone threshold: 3 >= ${THREE_HALFTONE_MIN_PX}px, lockup mark >= ${LOCKUP_HALFTONE_MIN_MARK_PX}px, wordmark >= ${WORDMARK_HALFTONE_MIN_PX}px`,
);
if (report.some((r) => !r.pass)) process.exit(1);
