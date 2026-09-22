import React from "react";
import type { Palette } from "../tokens";

/**
 * Cosmic / geometric / extended wordmark candidates.
 *
 * Metrics were measured once from the Google Fonts woff2 files with fontkit
 * (units: em). Variable fonts were measured at their default instance, so
 * widths are approximate (+/- 4%); layouts add a small safety margin.
 */
export type FontKey =
  | "Unbounded"
  | "Michroma"
  | "Syncopate"
  | "KronaOne"
  | "Sora"
  | "LexendZetta"
  | "SpaceGrotesk"
  | "Orbitron";

export type Treatment = 1 | 2 | 3;

export type TypeSpec = {
  key: FontKey;
  label: string;
  family: string; // CSS font-family stack
  weight: number;
  note: string; // one-line finding from the study
  cliche?: boolean;
  lower: number; // advance of "puls3"
  upper: number; // advance of "PULS3"
  xHeight: number;
  capHeight: number;
  /** Treatment 1 / 3 tracking and treatment 2 (uppercase) tracking, in em. */
  trackLower: number;
  trackUpper: number;
  /** Custom touch used for treatment 3. */
  custom: "counter" | "flower";
  /** Center and size of the "p" counter relative to the text origin (baseline), in em. */
  counter: { cx: number; cy: number; w: number; h: number };
};

const sans = (name: string) => `'${name}', 'Helvetica Neue', Arial, sans-serif`;

export const TYPE_SPECS: TypeSpec[] = [
  {
    key: "Unbounded",
    label: "Unbounded",
    family: sans("Unbounded"),
    weight: 500,
    note: "Wide, soft-cornered geometry; the round p bowl reads like a planet.",
    lower: 3.281,
    upper: 3.959,
    xHeight: 0.566,
    capHeight: 0.75,
    trackLower: -0.01,
    trackUpper: 0.22,
    custom: "counter",
    counter: { cx: 0.405, cy: -0.283, w: 0.42, h: 0.386 },
  },
  {
    key: "Michroma",
    label: "Michroma",
    family: sans("Michroma"),
    weight: 400,
    note: "Extended, squared-round forms; instrument-panel precision.",
    lower: 3.59,
    upper: 4.817,
    xHeight: 0.5625,
    capHeight: 0.75,
    trackLower: 0,
    trackUpper: 0.18,
    custom: "counter",
    counter: { cx: 0.4087, cy: -0.2812, w: 0.501, h: 0.4277 },
  },
  {
    key: "Syncopate",
    label: "Syncopate",
    family: sans("Syncopate"),
    weight: 700,
    note: "All-caps by design; very wide and airy, mission-patch feel.",
    lower: 4.388,
    upper: 4.356,
    xHeight: 0.4678,
    capHeight: 0.6709,
    trackLower: 0.02,
    trackUpper: 0.2,
    custom: "flower",
    counter: { cx: 0.481, cy: -0.4414, w: 0.3896, h: 0.1729 },
  },
  {
    key: "KronaOne",
    label: "Krona One",
    family: sans("Krona One"),
    weight: 400,
    note: "Heavy extended grotesk; confident and legible at small size.",
    lower: 3.588,
    upper: 4.413,
    xHeight: 0.5762,
    capHeight: 0.7632,
    trackLower: -0.01,
    trackUpper: 0.2,
    custom: "counter",
    counter: { cx: 0.4343, cy: -0.2881, w: 0.4067, h: 0.3438 },
  },
  {
    key: "Sora",
    label: "Sora",
    family: sans("Sora"),
    weight: 600,
    note: "Clean geometric sans (Stellar-adjacent); calm, product-ready.",
    lower: 2.753,
    upper: 3.268,
    xHeight: 0.534,
    capHeight: 0.73,
    trackLower: -0.015,
    trackUpper: 0.3,
    custom: "counter",
    counter: { cx: 0.3625, cy: -0.267, w: 0.357, h: 0.402 },
  },
  {
    key: "LexendZetta",
    label: "Lexend Zetta",
    family: sans("Lexend Zetta"),
    weight: 500,
    note: "Geometric with built-in wide spacing; spacious, weightless.",
    lower: 4.074,
    upper: 4.594,
    xHeight: 0.525,
    capHeight: 0.7,
    trackLower: 0,
    trackUpper: 0.1,
    custom: "counter",
    counter: { cx: 0.5495, cy: -0.2625, w: 0.461, h: 0.353 },
  },
  {
    key: "SpaceGrotesk",
    label: "Space Grotesk",
    family: sans("Space Grotesk"),
    weight: 500,
    note: "Techy grotesk quirks; reads more dev-tool than cosmos.",
    lower: 2.624,
    upper: 3.03,
    xHeight: 0.486,
    capHeight: 0.7,
    trackLower: -0.01,
    trackUpper: 0.3,
    custom: "flower",
    counter: { cx: 0.334, cy: -0.243, w: 0.372, h: 0.406 },
  },
  {
    key: "Orbitron",
    label: "Orbitron (cliché reference)",
    family: sans("Orbitron"),
    weight: 700,
    note: "Instant sci-fi, but the most generic 'space' shorthand.",
    cliche: true,
    lower: 3.173,
    upper: 4.046,
    xHeight: 0.58,
    capHeight: 0.72,
    trackLower: 0,
    trackUpper: 0.22,
    custom: "counter",
    counter: { cx: 0.3495, cy: -0.29, w: 0.427, h: 0.416 },
  },
];

export const typeSpec = (key: FontKey) =>
  TYPE_SPECS.find((s) => s.key === key) ?? TYPE_SPECS[0];

export const TREATMENT_LABEL: Record<Treatment, string> = {
  1: "T1 lowercase",
  2: "T2 UPPERCASE tracked",
  3: "T3 custom",
};

const MARGIN = 1.04; // safety margin for variable-font width approximations

/** Rendered width in em (including tracking and the custom element). */
export const wordmarkWidthEm = (s: TypeSpec, tr: Treatment) => {
  if (tr === 2) return (s.upper + 5 * s.trackUpper) * MARGIN;
  const base = s.lower + 5 * s.trackLower;
  const flower = tr === 3 && s.custom === "flower" ? 0.5 : 0;
  return (base + flower) * MARGIN;
};

/** Mini halftone pulse: a center dot with six satellites (used as a "signal" glyph). */
const Flower: React.FC<{
  cx: number;
  cy: number;
  em: number;
  color: string;
}> = ({ cx, cy, em, color }) => (
  <g>
    <circle cx={cx} cy={cy} r={0.085 * em} fill={color} />
    {Array.from({ length: 6 }).map((_, i) => {
      const a = (i * Math.PI) / 3;
      return (
        <circle
          key={i}
          cx={cx + Math.cos(a) * 0.165 * em}
          cy={cy + Math.sin(a) * 0.165 * em}
          r={0.04 * em}
          fill={color}
        />
      );
    })}
  </g>
);

/**
 * "puls3" in a candidate font. (x, y) is the left baseline origin, `size` the font size.
 * `t` reveals the wordmark (fade + slight rise) and pops the custom element.
 */
export const Wordmark2: React.FC<{
  spec: TypeSpec;
  treatment: Treatment;
  x: number;
  y: number;
  size: number;
  p: Palette;
  t?: number;
}> = ({ spec, treatment, x, y, size, p, t = 1 }) => {
  const e = 1 - Math.pow(1 - Math.min(1, Math.max(0, t)), 3);
  const pop = Math.min(1, Math.max(0, (t - 0.5) / 0.5));
  const upper = treatment === 2;
  const track = (upper ? spec.trackUpper : spec.trackLower) * size;
  const threeColor = treatment === 3 ? p.ink : p.accent;
  const textEl = (
    <text
      x={x}
      y={y}
      fontFamily={spec.family}
      fontWeight={spec.weight}
      fontSize={size}
      letterSpacing={track}
      fill={p.ink}
    >
      {upper ? "PULS" : "puls"}
      <tspan fill={threeColor}>3</tspan>
    </text>
  );
  let custom: React.ReactNode = null;
  if (treatment === 3 && spec.custom === "counter") {
    const r = 0.36 * Math.min(spec.counter.w, spec.counter.h) * size;
    custom = (
      <circle
        cx={x + spec.counter.cx * size}
        cy={y + spec.counter.cy * size}
        r={r * pop}
        fill={p.accent}
      />
    );
  } else if (treatment === 3 && spec.custom === "flower") {
    const endX = x + (spec.lower + 5 * spec.trackLower) * size;
    custom = (
      <g opacity={pop}>
        <Flower
          cx={endX + 0.27 * size}
          cy={y - spec.xHeight * size * 0.5}
          em={size}
          color={p.accent}
        />
      </g>
    );
  }
  return (
    <g
      opacity={e}
      transform={t < 1 ? `translate(0 ${(1 - e) * 0.08 * size})` : undefined}
    >
      {textEl}
      {custom}
    </g>
  );
};

/** Standalone wordmark SVG sized by height; the viewBox is derived from the metrics. */
export const WordmarkSvg: React.FC<{
  spec: TypeSpec;
  treatment: Treatment;
  height: number;
  p: Palette;
}> = ({ spec, treatment, height, p }) => {
  const size = 100;
  const top = -0.82 * size;
  const h = 1.12 * size;
  const w = wordmarkWidthEm(spec, treatment) * size + 8;
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height={height}
      width={(height * w) / h}
      viewBox={`-4 ${top} ${w} ${h}`}
      role="img"
      aria-label={`puls3 in ${spec.label}, ${TREATMENT_LABEL[treatment]}`}
    >
      <Wordmark2
        spec={spec}
        treatment={treatment}
        x={0}
        y={0}
        size={size}
        p={p}
      />
    </svg>
  );
};
