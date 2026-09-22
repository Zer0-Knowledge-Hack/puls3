import React from "react";
import { drawOn, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

const A = { x: 64, y: 18 };
const B = { x: 18, y: 102 };
const D = { x: 110, y: 102 };
const HUB = { x: 64, y: 76 };

const backOut = (x: number) => {
  const c1 = 1.70158;
  const c3 = c1 + 1;
  return x <= 0 ? 0 : 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
};

const line = (a: { x: number; y: number }, b: { x: number; y: number }) =>
  `M ${a.x} ${a.y} L ${b.x} ${b.y}`;

const Art: React.FC<ArtProps> = ({ t, p }) => {
  const pop = (a: number) => backOut(segment(t, a, a + 0.25));
  const edge = {
    fill: "none",
    strokeWidth: 6,
    strokeLinecap: "round" as const,
  };
  const spoke = {
    fill: "none",
    strokeWidth: 4,
    strokeLinecap: "round" as const,
  };
  return (
    <g>
      <path
        d={line(A, B)}
        stroke={p.ink}
        {...edge}
        {...drawOn(segment(t, 0.2, 0.5))}
      />
      <path
        d={line(B, D)}
        stroke={p.ink}
        {...edge}
        {...drawOn(segment(t, 0.35, 0.65))}
      />
      <path
        d={line(D, A)}
        stroke={p.ink}
        {...edge}
        {...drawOn(segment(t, 0.5, 0.8))}
      />
      {[A, B, D].map((n, i) => (
        <path
          key={i}
          d={line(HUB, n)}
          stroke={p.secondary}
          {...spoke}
          {...drawOn(segment(t, 0.65, 0.95))}
        />
      ))}
      <circle cx={A.x} cy={A.y} r={13 * pop(0)} fill={p.accent} />
      <circle cx={B.x} cy={B.y} r={11 * pop(0.12)} fill={p.ink} />
      <circle cx={D.x} cy={D.y} r={11 * pop(0.24)} fill={p.ink} />
      <circle cx={HUB.x} cy={HUB.y} r={8 * pop(0.7)} fill={p.secondary} />
    </g>
  );
};

export const Constellation: Concept = {
  code: "C05",
  slug: "Constellation",
  name: "Constellation",
  mark: "Three agent nodes joined into a triangle around a lavender hub.",
  rationale:
    "A network of agents meeting at one hub: the marketplace as a constellation.",
  Mark: makeMark(Art, "Constellation"),
  Lockup: makeStandardLockup(Art, "Constellation"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
