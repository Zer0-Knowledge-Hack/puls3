import React from "react";
import {
  colors,
  darkPalette,
  GRID,
  lightPalette,
  type Palette,
} from "../tokens";

/**
 * C01-small: the Halftone Pulse identity rebuilt for 16-32 px.
 * Same idea (amber core, dots fading to lavender at the edge) with far fewer, larger dots.
 * Each level is drawn on the 128 grid and chosen by the rendered size.
 */
type Ring = {
  d: number;
  n: number;
  r: number;
  tone: "accent" | "secondary";
  offset: number;
};
type Level = { core: number; rings: Ring[] };

export const C01_SMALL_LEVELS: Record<16 | 24 | 32, Level> = {
  32: {
    core: 17,
    rings: [
      { d: 35, n: 8, r: 8.5, tone: "accent", offset: 22.5 },
      { d: 55, n: 14, r: 5.8, tone: "secondary", offset: 0 },
    ],
  },
  24: {
    core: 19,
    rings: [
      { d: 39, n: 8, r: 9.5, tone: "accent", offset: 22.5 },
      { d: 57, n: 12, r: 6.4, tone: "secondary", offset: 0 },
    ],
  },
  16: {
    core: 26,
    rings: [{ d: 47, n: 8, r: 13, tone: "secondary", offset: 0 }],
  },
};

export const levelFor = (size: number): 16 | 24 | 32 =>
  size <= 18 ? 16 : size <= 27 ? 24 : 32;

/** The dots only, on the 128 grid. `t` (0..1) swells the dots from the core outward. */
export const C01SmallArt: React.FC<{
  level: 16 | 24 | 32;
  p: Palette;
  t?: number;
}> = ({ level, p, t = 1 }) => {
  const L = C01_SMALL_LEVELS[level];
  const k = (a: number) => Math.min(1, Math.max(0, (t - a) / 0.5));
  return (
    <g>
      <circle cx={64} cy={64} r={L.core * k(0)} fill={p.accent} />
      {L.rings.map((ring, j) =>
        Array.from({ length: ring.n }).map((_, i) => {
          const a = ((i * 360) / ring.n + ring.offset) * (Math.PI / 180);
          return (
            <circle
              key={`${j}-${i}`}
              cx={(64 + Math.cos(a) * ring.d).toFixed(2)}
              cy={(64 + Math.sin(a) * ring.d).toFixed(2)}
              r={(ring.r * k(0.2 + j * 0.25)).toFixed(2)}
              fill={ring.tone === "accent" ? p.accent : p.secondary}
            />
          );
        }),
      )}
    </g>
  );
};

export const C01Small: React.FC<{
  size: number;
  palette?: Palette;
  level?: 16 | 24 | 32;
  t?: number;
}> = ({ size, palette = darkPalette, level, t = 1 }) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width={size}
    height={size}
    viewBox={`0 0 ${GRID} ${GRID}`}
    role="img"
    aria-label="puls3 C01 small mark"
  >
    <C01SmallArt level={level ?? levelFor(size)} p={palette} t={t} />
  </svg>
);

/** Favicon tile: the small mark on a rounded square, for dark or light browser chrome. */
export const FaviconTile: React.FC<{
  size: number;
  mode: "dark" | "light";
}> = ({ size, mode }) => {
  const p = mode === "dark" ? darkPalette : lightPalette;
  const bg = mode === "dark" ? colors.background : colors.white;
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox={`0 0 ${GRID} ${GRID}`}
      role="img"
      aria-label={`puls3 favicon (${mode})`}
    >
      <rect width={GRID} height={GRID} rx={30} fill={bg} />
      <g transform="translate(64 64) scale(0.86) translate(-64 -64)">
        <C01SmallArt level={levelFor(size)} p={p} />
      </g>
    </svg>
  );
};
