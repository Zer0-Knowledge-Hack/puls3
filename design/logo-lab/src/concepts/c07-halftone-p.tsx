import React from "react";
import { easeOutCubic, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

// Geometric "p": a stem plus a ring-shaped bowl. The bowl's counter holds the pulse dot.
const STEM = { x0: 22, x1: 43, y0: 24, y1: 116 };
const BOWL = { cx: 72, cy: 54, outer: 36, inner: 17 };
const STEP = 5.4;
const TOP = 16;
const BOTTOM = 118;

const inside = (x: number, y: number) => {
  if (x >= STEM.x0 && x <= STEM.x1 && y >= STEM.y0 && y <= STEM.y1) return true;
  const d = Math.hypot(x - BOWL.cx, y - BOWL.cy);
  return d <= BOWL.outer && d >= BOWL.inner;
};

const DOTS = (() => {
  const out: { x: number; y: number; v: number }[] = [];
  for (let j = 0; TOP + j * STEP <= BOTTOM + 1; j++) {
    const y = TOP + 1 + j * STEP;
    const shift = j % 2 === 0 ? 0 : STEP / 2;
    for (let i = 0; i * STEP <= 128; i++) {
      const x = 2 + i * STEP + shift;
      if (inside(x, y)) out.push({ x, y, v: (y - TOP) / (BOTTOM - TOP) });
    }
  }
  return out;
})();

const Art: React.FC<ArtProps> = ({ t, p }) => {
  const pulse = easeOutCubic(segment(t, 0.55, 0.85));
  const echo = segment(t, 0.7, 1);
  return (
    <g>
      {DOTS.map(({ x, y, v }, i) => {
        // Halftone gradient: dense at the top of the bowl, fading down the stem.
        const appear = easeOutCubic(segment(t, v * 0.5, v * 0.5 + 0.35));
        const r = (1.05 + 1.7 * (1 - v)) * appear;
        if (r <= 0.01) return null;
        return (
          <circle
            key={i}
            cx={x.toFixed(2)}
            cy={y.toFixed(2)}
            r={r.toFixed(2)}
            fill={p.ink}
          />
        );
      })}
      {echo > 0 && echo < 1 ? (
        <circle
          cx={BOWL.cx}
          cy={BOWL.cy}
          r={9 + echo * 8}
          fill="none"
          stroke={p.accent}
          strokeWidth={2}
          opacity={1 - echo}
        />
      ) : null}
      <circle cx={BOWL.cx} cy={BOWL.cy} r={9.5 * pulse} fill={p.accent} />
    </g>
  );
};

export const HalftoneP: Concept = {
  code: "C07",
  slug: "HalftoneP",
  name: "Halftone p",
  mark: "A halftone-filled monogram p whose bowl cradles an amber pulse dot.",
  rationale:
    "A compact app icon: the p for puls3 with a live signal at its heart.",
  Mark: makeMark(Art, "Halftone p"),
  Lockup: makeStandardLockup(Art, "Halftone p"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
