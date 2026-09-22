import React from "react";
import { darkPalette, GRID, type Palette } from "../tokens";
import { HalftonePulse } from "../concepts/c01-halftone-pulse";
import { easeOutCubic } from "../lib/geometry";
import {
  fontOf,
  layoutOf,
  liveFamily,
  SolidRender,
  type Option3,
} from "./options";

const SVG_NS = "http://www.w3.org/2000/svg";

/**
 * "live" draws solid wordmarks as <text> with the Google font (proves the font loads);
 * "outline" always draws the generated glyph paths (font-independent, used for export).
 */
export type RenderMode = "live" | "outline";

/** The wordmark in font units (1000/em, baseline at y = 0, x from 0). */
export const WordmarkGlyphs: React.FC<{
  opt: Option3;
  p: Palette;
  t?: number;
  mode?: RenderMode;
  from?: { x: number; y: number };
}> = ({ opt, p, t = 1, mode = "outline", from }) => {
  const font = fontOf(opt);
  const { glyphs, width } = layoutOf(opt);
  if (mode === "live" && opt.live && !opt.render) {
    const e = easeOutCubic(t);
    return (
      <text
        x={0}
        y={0}
        fontFamily={liveFamily(opt)}
        fontWeight={opt.live.weight}
        fontSize={1000}
        letterSpacing={opt.tracking * 1000}
        fill={p.ink}
        opacity={e}
      >
        {opt.text.slice(0, 4)}
        <tspan fill={p.accent}>3</tspan>
      </text>
    );
  }
  const render = opt.render ?? SolidRender;
  return <>{render({ font, glyphs, width, p, t, from })}</>;
};

/** Vertical extent of a wordmark in font units (y down). */
export const wordmarkExtent = (opt: Option3) => {
  const f = fontOf(opt);
  const ys = layoutOf(opt).glyphs.flatMap((g) => [g.bbox[1], g.bbox[3]]);
  return {
    top: Math.min(-f.capHeight, ...ys) - 40,
    bottom: Math.max(-f.descender * 0.2, ...ys) + 40,
  };
};

/** Standalone wordmark, sized by font size in px. */
export const WordmarkSvg: React.FC<{
  opt: Option3;
  fontSize: number;
  p?: Palette;
  mode?: RenderMode;
}> = ({ opt, fontSize, p = darkPalette, mode = "outline" }) => {
  const { width } = layoutOf(opt);
  const { top, bottom } = wordmarkExtent(opt);
  const pad = 40;
  const w = width + pad * 2;
  const h = bottom - top;
  return (
    <svg
      xmlns={SVG_NS}
      width={(w * fontSize) / 1000}
      height={(h * fontSize) / 1000}
      viewBox={`${-pad} ${top} ${w} ${h}`}
      role="img"
      aria-label={`puls3 wordmark, ${opt.font} ${opt.weight}`}
      overflow="visible"
    >
      <WordmarkGlyphs opt={opt} p={p} mode={mode} />
    </svg>
  );
};

/* ------------------------------ Lockup ------------------------------ */

const GAP = 40;

/** Geometry of the C01 + wordmark lockup, in mark units (the mark is 128 x 128). */
export const lockupGeometry = (opt: Option3) => {
  const f = fontOf(opt);
  const lower = opt.text === "puls3";
  // Optical balance: x-height (or cap height) ~ 40% of the mark.
  const target = lower ? 52 : 46;
  const s = target / (lower ? f.xHeight : f.capHeight);
  const baseline = 64 + target / 2;
  const { width } = layoutOf(opt);
  const { top, bottom } = wordmarkExtent(opt);
  const x0 = GRID + GAP;
  const y0 = Math.min(-6, baseline + top * s);
  const y1 = Math.max(GRID + 6, baseline + bottom * s);
  const w = x0 + width * s + 16;
  return { s, baseline, x0, y0, h: y1 - y0, w };
};

export const LockupSvg: React.FC<{
  opt: Option3;
  height: number; // px height of the 128-unit mark box
  p?: Palette;
  mode?: RenderMode;
  markT?: number;
  wordT?: number;
}> = ({
  opt,
  height,
  p = darkPalette,
  mode = "outline",
  markT = 1,
  wordT = 1,
}) => {
  const g = lockupGeometry(opt);
  const px = height / GRID;
  // Pulse origin (mark center) expressed in the wordmark's font units, for "assemble" reveals.
  const from = { x: (64 - g.x0) / g.s, y: (64 - g.baseline) / g.s };
  return (
    <svg
      xmlns={SVG_NS}
      width={g.w * px}
      height={g.h * px}
      viewBox={`-6 ${g.y0.toFixed(1)} ${(g.w + 6).toFixed(1)} ${g.h.toFixed(1)}`}
      role="img"
      aria-label={`puls3 lockup, C01 with ${opt.font} ${opt.weight}`}
      overflow="visible"
    >
      <HalftonePulse.Mark size={GRID} t={markT} palette={p} />
      <g transform={`translate(${g.x0} ${g.baseline}) scale(${g.s})`}>
        <WordmarkGlyphs opt={opt} p={p} t={wordT} mode={mode} from={from} />
      </g>
    </svg>
  );
};
