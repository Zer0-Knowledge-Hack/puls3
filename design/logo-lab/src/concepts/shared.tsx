import React from "react";
import { darkPalette, fonts, GRID, type Palette } from "../tokens";
import { easeOutCubic } from "../lib/geometry";
import type { ArtProps, LockupProps, MarkProps } from "./types";

const SVG_NS = "http://www.w3.org/2000/svg";

/** Wraps 128-grid artwork into a standalone square SVG mark. */
export const makeMark = (
  Art: React.FC<ArtProps>,
  label: string,
): React.FC<MarkProps> => {
  const Mark: React.FC<MarkProps> = ({
    size,
    t = 1,
    palette = darkPalette,
  }) => (
    <svg
      xmlns={SVG_NS}
      width={size}
      height={size}
      viewBox={`0 0 ${GRID} ${GRID}`}
      role="img"
      aria-label={`puls3 ${label} mark`}
    >
      <Art t={t} p={palette} />
    </svg>
  );
  Mark.displayName = `${label}Mark`;
  return Mark;
};

/** The default wordmark: lowercase serif "puls3" with the 3 in amber. */
export const SerifWordmark: React.FC<{
  x: number;
  y: number;
  size: number;
  p: Palette;
  t: number;
}> = ({ x, y, size, p, t }) => {
  const e = easeOutCubic(t);
  return (
    <text
      x={x}
      y={y}
      fontFamily={fonts.display}
      fontSize={size}
      letterSpacing={-0.01 * size}
      fill={p.ink}
      opacity={e}
      transform={t < 1 ? `translate(${(1 - e) * 14} 0)` : undefined}
    >
      puls<tspan fill={p.accent}>3</tspan>
    </text>
  );
};

export const STANDARD_LOCKUP = { w: 476, h: 160, markCenterX: 80 } as const;

/** Mark on the left, serif wordmark on the right. */
export const makeStandardLockup = (
  Art: React.FC<ArtProps>,
  label: string,
): React.FC<LockupProps> => {
  const Lockup: React.FC<LockupProps> = ({
    height,
    markT = 1,
    wordT = 1,
    palette = darkPalette,
  }) => (
    <svg
      xmlns={SVG_NS}
      height={height}
      width={(height * STANDARD_LOCKUP.w) / STANDARD_LOCKUP.h}
      viewBox={`0 0 ${STANDARD_LOCKUP.w} ${STANDARD_LOCKUP.h}`}
      role="img"
      aria-label={`puls3 ${label} lockup`}
    >
      <g transform="translate(16 16)">
        <Art t={markT} p={palette} />
      </g>
      <SerifWordmark x={170} y={114} size={118} p={palette} t={wordT} />
    </svg>
  );
  Lockup.displayName = `${label}Lockup`;
  return Lockup;
};
