import React from "react";
import { arcPath, easeInOutCubic, polar, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

// Two stacked open elliptical arcs (reversed "C" shapes) meet at a waist and read as a 3.
// Both openings face left and no line ever crosses a circle.
type OrbitSpec = {
  cx: number;
  cy: number;
  rx: number;
  ry: number;
  from: number;
  to: number;
  reverse: boolean; // draw from `to` back to `from`, so the satellite rests at `from`
};

const TOP: OrbitSpec = {
  cx: 62,
  cy: 40,
  rx: 30,
  ry: 20,
  from: 200,
  to: 470,
  reverse: true,
};
const BOTTOM: OrbitSpec = {
  cx: 64,
  cy: 86,
  rx: 37,
  ry: 24,
  from: 250,
  to: 510,
  reverse: false,
};

const Orbit: React.FC<{
  o: OrbitSpec;
  t: number;
  stroke: string;
  satellite: string;
}> = ({ o, t, stroke, satellite }) => {
  const e = easeInOutCubic(t);
  if (e <= 0) return null;
  const span = (o.to - o.from) * e;
  const a = o.reverse ? o.to - span : o.from;
  const b = o.reverse ? o.to : o.from + span;
  const tip = polar(o.cx, o.cy, o.rx, o.ry, o.reverse ? a : b);
  return (
    <g>
      <path
        d={arcPath(o.cx, o.cy, o.rx, o.ry, a, b)}
        fill="none"
        stroke={stroke}
        strokeWidth={7.5}
        strokeLinecap="round"
      />
      <circle
        cx={tip.x.toFixed(2)}
        cy={tip.y.toFixed(2)}
        r={7.5}
        fill={satellite}
      />
    </g>
  );
};

const Art: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    <Orbit
      o={TOP}
      t={segment(t, 0, 0.7)}
      stroke={p.ink}
      satellite={p.secondary}
    />
    <Orbit
      o={BOTTOM}
      t={segment(t, 0.25, 1)}
      stroke={p.ink}
      satellite={p.accent}
    />
  </g>
);

export const Orbit3: Concept = {
  code: "C03",
  slug: "Orbit3",
  name: "Orbit 3",
  mark: "Two stacked open orbits, each carrying a satellite, forming a 3.",
  rationale:
    "Agents in orbit around a shared network; the 3 drawn as motion, not type.",
  Mark: makeMark(Art, "Orbit 3"),
  Lockup: makeStandardLockup(Art, "Orbit 3"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
