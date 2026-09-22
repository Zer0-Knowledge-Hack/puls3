import React from "react";
import { drawOn, segment } from "../lib/geometry";
import { makeMark, makeStandardLockup, STANDARD_LOCKUP } from "./shared";
import type { ArtProps, Concept } from "./types";

// ECG trace on a baseline that runs into the waist of a "3".
const ECG = "M 6 66 H 20 L 29 32 L 39 100 L 47 66 H 76";
const TOP_LOBE = "M 76 66 C 110 66 112 26 84 26 C 74 26 67 30 63 36";
const BOTTOM_LOBE = "M 76 66 C 116 66 117 108 84 108 C 74 108 66 104 61 96";

const Art: React.FC<ArtProps> = ({ t, p }) => {
  const common = {
    fill: "none",
    strokeWidth: 8.5,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };
  return (
    <g>
      <path
        d={ECG}
        stroke={p.ink}
        {...common}
        {...drawOn(segment(t, 0, 0.55))}
      />
      <path
        d={TOP_LOBE}
        stroke={p.accent}
        {...common}
        {...drawOn(segment(t, 0.5, 0.8))}
      />
      <path
        d={BOTTOM_LOBE}
        stroke={p.accent}
        {...common}
        {...drawOn(segment(t, 0.62, 0.97))}
      />
    </g>
  );
};

export const Heartbeat3: Concept = {
  code: "C02",
  slug: "Heartbeat3",
  name: "Heartbeat 3",
  mark: "An ECG trace whose final beat resolves into an amber numeral 3.",
  rationale:
    "The pulse becomes the 3: the heartbeat of pulse, reborn on Stellar.",
  Mark: makeMark(Art, "Heartbeat 3"),
  Lockup: makeStandardLockup(Art, "Heartbeat 3"),
  lockupSize: { w: STANDARD_LOCKUP.w, h: STANDARD_LOCKUP.h },
  lockupMode: "slide",
  markCenterX: STANDARD_LOCKUP.markCenterX,
};
