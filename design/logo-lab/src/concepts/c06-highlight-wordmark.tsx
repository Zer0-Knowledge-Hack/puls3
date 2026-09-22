import React from "react";
import { darkPalette, fonts, GRID } from "../tokens";
import { drawOn, easeOutCubic, segment } from "../lib/geometry";
import { makeMark } from "./shared";
import type { ArtProps, Concept, LockupProps } from "./types";

/** A hand-drawn highlighter swipe: one heavy pass plus a lighter, offset second pass. */
const Highlight: React.FC<{
  d: string;
  d2: string;
  width: number;
  color: string;
  t: number;
}> = ({ d, d2, width, color, t }) => (
  <g>
    <path
      d={d}
      fill="none"
      stroke={color}
      strokeWidth={width}
      strokeLinecap="round"
      {...drawOn(t)}
    />
    <path
      d={d2}
      fill="none"
      stroke={color}
      strokeWidth={width * 0.45}
      strokeLinecap="round"
      opacity={0.85}
      {...drawOn(segment(t, 0.35, 1))}
    />
  </g>
);

const Art: React.FC<ArtProps> = ({ t, p }) => {
  const text = easeOutCubic(segment(t, 0, 0.5));
  return (
    <g>
      <Highlight
        d="M 30 106 C 52 99 82 101 106 93"
        d2="M 38 115 C 60 110 84 112 102 106"
        width={15}
        color={p.accent}
        t={segment(t, 0.35, 1)}
      />
      <text
        x={64}
        y={98}
        textAnchor="middle"
        fontFamily={fonts.display}
        fontSize={122}
        fill={p.ink}
        opacity={text}
      >
        3
      </text>
    </g>
  );
};

const LOCKUP = { w: 350, h: 160 };
const THREE_X = 252; // left edge of the "3" in the lockup

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
      aria-label="puls3 Highlight Wordmark lockup"
    >
      <Highlight
        d={`M ${THREE_X - 2} 130 C ${THREE_X + 22} 124 ${THREE_X + 54} 126 ${THREE_X + 82} 117`}
        d2={`M ${THREE_X + 6} 140 C ${THREE_X + 28} 136 ${THREE_X + 54} 137 ${THREE_X + 76} 131`}
        width={17}
        color={palette.accent}
        t={markT}
      />
      <g
        opacity={e}
        transform={wordT < 1 ? `translate(0 ${(1 - e) * 10})` : undefined}
      >
        <text
          x={THREE_X - 10}
          y={118}
          textAnchor="end"
          fontFamily={fonts.display}
          fontSize={132}
          letterSpacing={-1}
          fill={palette.ink}
        >
          puls
        </text>
        <text
          x={THREE_X}
          y={118}
          fontFamily={fonts.display}
          fontSize={132}
          fill={palette.ink}
        >
          3
        </text>
      </g>
    </svg>
  );
};

export const HighlightWordmark: Concept = {
  code: "C06",
  slug: "HighlightWordmark",
  name: "Highlight Wordmark",
  mark: "A serif 3 underlined by a hand-drawn amber highlighter swipe.",
  rationale: "Editorial and human: the 3 is the part worth highlighting.",
  Mark: makeMark(Art, "Highlight Wordmark"),
  Lockup,
  lockupSize: LOCKUP,
  lockupMode: "self",
  markCenterX: GRID / 2,
};
