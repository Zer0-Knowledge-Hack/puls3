import React from "react";
import { darkPalette, fonts, GRID } from "../tokens";
import { easeInOutCubic, easeOutCubic } from "../lib/geometry";
import { makeMark } from "./shared";
import type { ArtProps, Concept, LockupProps } from "./types";

type Wave = {
  x0: number;
  x1: number;
  y: number;
  amp: number;
  cycles: number;
};

const wavePoint = (w: Wave, u: number) => ({
  x: w.x0 + (w.x1 - w.x0) * u,
  y: w.y - w.amp * Math.sin(2 * Math.PI * w.cycles * u),
});

/** Sine polyline drawn up to progress `u`, plus the riding dot at its tip. */
const WaveStroke: React.FC<{
  w: Wave;
  u: number;
  stroke: string;
  dot: string;
  width: number;
  dotR: number;
}> = ({ w, u, stroke, dot, width, dotR }) => {
  if (u <= 0) return null;
  const n = 64;
  const pts: string[] = [];
  for (let i = 0; i <= n; i++) {
    const q = wavePoint(w, (u * i) / n);
    pts.push(`${q.x.toFixed(2)},${q.y.toFixed(2)}`);
  }
  const tip = wavePoint(w, u);
  return (
    <g>
      <polyline
        points={pts.join(" ")}
        fill="none"
        stroke={stroke}
        strokeWidth={width}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle cx={tip.x.toFixed(2)} cy={tip.y.toFixed(2)} r={dotR} fill={dot} />
    </g>
  );
};

const MARK_WAVE: Wave = { x0: 14, x1: 102, y: 70, amp: 28, cycles: 1.25 };

const Art: React.FC<ArtProps> = ({ t, p }) => (
  <WaveStroke
    w={MARK_WAVE}
    u={easeInOutCubic(t)}
    stroke={p.accent}
    dot={p.secondary}
    width={9}
    dotR={10}
  />
);

const LOCKUP = { w: 380, h: 160 };
const LOCKUP_WAVE: Wave = { x0: 20, x1: 350, y: 136, amp: 7, cycles: 2.25 };

const Lockup: React.FC<LockupProps> = ({
  height,
  markT = 1,
  wordT = 1,
  palette = darkPalette,
}) => {
  const e = easeOutCubic(wordT);
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      height={height}
      width={(height * LOCKUP.w) / LOCKUP.h}
      viewBox={`0 0 ${LOCKUP.w} ${LOCKUP.h}`}
      role="img"
      aria-label="puls3 Wave Wordmark lockup"
    >
      <text
        x={18}
        y={104}
        fontFamily={fonts.sans}
        fontWeight={800}
        fontSize={112}
        letterSpacing={-5}
        fill={palette.ink}
        opacity={e}
        transform={wordT < 1 ? `translate(0 ${(1 - e) * 10})` : undefined}
      >
        puls<tspan fill={palette.accent}>3</tspan>
      </text>
      <WaveStroke
        w={LOCKUP_WAVE}
        u={easeInOutCubic(markT)}
        stroke={palette.secondary}
        dot={palette.accent}
        width={6}
        dotR={8}
      />
    </svg>
  );
};

export const WaveWordmark: Concept = {
  code: "C08",
  slug: "WaveWordmark",
  name: "Wave Wordmark",
  mark: "A single amber sine wave that ends in a lavender signal dot.",
  rationale:
    "Bold sans wordmark riding one continuous signal: calm, technical, legible.",
  Mark: makeMark(Art, "Wave Wordmark"),
  Lockup,
  lockupSize: LOCKUP,
  lockupMode: "self",
  markCenterX: GRID / 2,
};
