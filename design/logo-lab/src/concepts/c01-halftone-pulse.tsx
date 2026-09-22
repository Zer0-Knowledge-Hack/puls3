import React from "react";
import { easeOutCubic, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

const CENTER = 64;
const RADIUS = 58;
const STEP = 9.4;

/** Hexagonal dot field clipped to a circle; d = normalized distance from center. */
const DOTS = (() => {
  const out: { x: number; y: number; d: number }[] = [];
  const rowH = STEP * 0.866;
  for (let j = -8; j <= 8; j++) {
    const y = CENTER + j * rowH;
    const shift = j % 2 === 0 ? 0 : STEP / 2;
    for (let i = -8; i <= 8; i++) {
      const x = CENTER + i * STEP + shift;
      const d = Math.hypot(x - CENTER, y - CENTER) / RADIUS;
      if (d <= 1) out.push({ x, y, d });
    }
  }
  return out;
})();

const Art: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    {DOTS.map(({ x, y, d }, i) => {
      // Dots appear from the center outward: a heartbeat expanding into a dot field.
      const appear = easeOutCubic(segment(t, d * 0.5, d * 0.5 + 0.5));
      const r = (1.2 + 3.4 * Math.pow(1 - d, 1.1)) * appear;
      if (r <= 0.01) return null;
      return (
        <circle
          key={i}
          cx={x.toFixed(2)}
          cy={y.toFixed(2)}
          r={r.toFixed(2)}
          fill={d < 0.62 ? p.accent : p.secondary}
        />
      );
    })}
  </g>
);

export const HalftonePulse: Concept = {
  code: "C01",
  slug: "HalftonePulse",
  name: "Halftone Pulse",
  mark: "A circular halftone dot field whose dots swell toward an amber core.",
  rationale:
    "A heartbeat frozen as a dot field: printed-matter texture, living signal.",
  Mark: makeMark(Art, "Halftone Pulse"),
  Lockup: makeStandardLockup(Art, "Halftone Pulse"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
