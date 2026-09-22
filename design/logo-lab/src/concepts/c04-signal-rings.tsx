import React from "react";
import { arcPath, easeOutCubic, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

const C = 64;

type Ring = { r: number; arcs: [number, number][]; color: "ink" | "secondary" };

// Broken rings: gaps are staggered so they never line up into a band.
const RINGS: Ring[] = [
  {
    r: 29,
    arcs: [
      [-50, 60],
      [85, 185],
      [210, 290],
    ],
    color: "ink",
  },
  {
    r: 50,
    arcs: [
      [-20, 70],
      [100, 170],
      [195, 250],
      [275, 320],
    ],
    color: "secondary",
  },
];

const Art: React.FC<ArtProps> = ({ t, p }) => {
  const node = easeOutCubic(segment(t, 0, 0.3));
  const echo = segment(t, 0.55, 1);
  return (
    <g>
      {RINGS.map((ring, i) => {
        const k = easeOutCubic(segment(t, 0.15 + i * 0.2, 0.65 + i * 0.2));
        if (k <= 0) return null;
        const r = ring.r * (0.55 + 0.45 * k);
        return (
          <g key={i} opacity={k}>
            {ring.arcs.map(([a, b], j) => (
              <path
                key={j}
                d={arcPath(C, C, r, r, a, b)}
                fill="none"
                stroke={ring.color === "ink" ? p.ink : p.secondary}
                strokeWidth={7.5}
                strokeLinecap="round"
              />
            ))}
          </g>
        );
      })}
      {echo > 0 && echo < 1 ? (
        <circle
          cx={C}
          cy={C}
          r={50 + echo * 16}
          fill="none"
          stroke={p.secondary}
          strokeWidth={2}
          opacity={(1 - echo) * 0.5}
        />
      ) : null}
      <circle cx={C} cy={C} r={11 * node} fill={p.accent} />
    </g>
  );
};

export const SignalRings: Concept = {
  code: "C04",
  slug: "SignalRings",
  name: "Signal Rings",
  mark: "An amber node emitting two staggered, broken concentric rings.",
  rationale:
    "An agent broadcasting on the network: always on, always discoverable.",
  Mark: makeMark(Art, "Signal Rings"),
  Lockup: makeStandardLockup(Art, "Signal Rings"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
