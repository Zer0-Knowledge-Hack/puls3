import React from "react";
import { brandDark, GRID, type Palette } from "../tokens";
import { HalftonePulse } from "../concepts/c01-halftone-pulse";
import { C01SmallArt, levelFor } from "../round3/c01small";
import { lockupGeometry, WordmarkGlyphs } from "../round3/lockup";
import { fontOf, layoutOf, option, type Option3 } from "../round3/options";

/**
 * The official puls3 logo (brand guide 2026): C01 Halftone Pulse + "puls3" in Unbounded 700,
 * with only the "3" in halftone dots (round-3 option A3b). Everything is outlined geometry.
 */
export const LOGO_HALFTONE: Option3 = option("A3b");
export const LOGO_SOLID: Option3 = {
  ...LOGO_HALFTONE,
  id: "A3b-solid",
  render: undefined,
};

const SVG_NS = "http://www.w3.org/2000/svg";

/* ------------------------------ Size rules ------------------------------ */

/** The halftone "3" is used only when the rendered "3" is at least this tall. */
export const THREE_HALFTONE_MIN_PX = 40;
/** C01 full is used for marks at least this large; below, C01-small (32/24/16 levels). */
export const MARK_FULL_MIN_PX = 48;

const threeGlyph = layoutOf(LOGO_HALFTONE).glyphs.find((g) => g.char === "3")!;
/** Height of the "3" in font units (1000/em). */
export const THREE_UNITS = threeGlyph.bbox[3] - threeGlyph.bbox[1];
const GEO = lockupGeometry(LOGO_HALFTONE);
/** Lockup geometry (mark units) and the bbox of the "3" (font units), for construction drawings. */
export const lockupGeo = GEO;
export const THREE_BBOX = threeGlyph.bbox;

/** Rendered "3" height (px) for a lockup whose mark box is `markPx` tall. */
export const threePxForMark = (markPx: number) =>
  (THREE_UNITS * GEO.s * markPx) / GRID;
/** Smallest lockup mark height (px) that still gets the halftone "3". */
export const LOCKUP_HALFTONE_MIN_MARK_PX = Math.ceil(
  (THREE_HALFTONE_MIN_PX * GRID) / (THREE_UNITS * GEO.s),
);
/** Halftone dot pitch (px) of the "3" at a given rendered "3" height. */
export const dotPitchForThree = (threePx: number) =>
  (56 / THREE_UNITS) * threePx;

type ThreeMode = "auto" | "halftone" | "solid";
type MarkMode = "auto" | "full" | "small";

/* --------------------------------- Mark --------------------------------- */

/** The mark on the 128 grid: C01 full, or C01-small at the level that fits `px`. */
export const MarkArt: React.FC<{
  px: number;
  p: Palette;
  mode?: MarkMode;
  t?: number;
}> = ({ px, p, mode = "auto", t = 1 }) => {
  const small = mode === "small" || (mode === "auto" && px < MARK_FULL_MIN_PX);
  return small ? (
    <C01SmallArt level={levelFor(px)} p={p} t={t} />
  ) : (
    <HalftonePulse.Mark size={GRID} palette={p} t={t} />
  );
};

export const BrandMark: React.FC<{
  size: number;
  palette?: Palette;
  mode?: MarkMode;
}> = ({ size, palette = brandDark, mode = "auto" }) => (
  <svg
    xmlns={SVG_NS}
    width={size}
    height={size}
    viewBox={`0 0 ${GRID} ${GRID}`}
    role="img"
    aria-label="puls3 mark"
  >
    <MarkArt px={size} p={palette} mode={mode} />
  </svg>
);

/* -------------------------------- Lockup -------------------------------- */

export const lockupAspect = () => (GEO.w + 6) / GEO.h;

/** Horizontal lockup. `height` is the mark box height in px. */
export const BrandLogo: React.FC<{
  height: number;
  palette?: Palette;
  three?: ThreeMode;
  mark?: MarkMode;
  markT?: number;
  wordT?: number;
}> = ({
  height,
  palette = brandDark,
  three = "auto",
  mark = "auto",
  markT = 1,
  wordT = 1,
}) => {
  const px = height / GRID;
  const halftone =
    three === "halftone" ||
    (three === "auto" && threePxForMark(height) >= THREE_HALFTONE_MIN_PX);
  const opt = halftone ? LOGO_HALFTONE : LOGO_SOLID;
  return (
    <svg
      xmlns={SVG_NS}
      width={(GEO.w + 6) * px}
      height={GEO.h * px}
      viewBox={`-6 ${GEO.y0.toFixed(1)} ${(GEO.w + 6).toFixed(1)} ${GEO.h.toFixed(1)}`}
      role="img"
      aria-label="puls3 logo"
    >
      <MarkArt px={height} p={palette} mode={mark} t={markT} />
      <g transform={`translate(${GEO.x0} ${GEO.baseline}) scale(${GEO.s})`}>
        <WordmarkGlyphs opt={opt} p={palette} t={wordT} />
      </g>
    </svg>
  );
};

/* ------------------------------- Wordmark ------------------------------- */

const WM = (() => {
  const f = fontOf(LOGO_HALFTONE);
  const { width } = layoutOf(LOGO_HALFTONE);
  const ys = layoutOf(LOGO_HALFTONE).glyphs.flatMap((g) => [
    g.bbox[1],
    g.bbox[3],
  ]);
  const top = Math.min(...ys) - 30;
  const bottom = Math.max(...ys) + 30;
  return { f, width, top, bottom, pad: 30 };
})();

/** Wordmark only. `height` is the total wordmark height (ascender to descender) in px. */
export const BrandWordmark: React.FC<{
  height: number;
  palette?: Palette;
  three?: ThreeMode;
}> = ({ height, palette = brandDark, three = "auto" }) => {
  const h = WM.bottom - WM.top;
  const w = WM.width + WM.pad * 2;
  const threePx = (THREE_UNITS * height) / h;
  const halftone =
    three === "halftone" ||
    (three === "auto" && threePx >= THREE_HALFTONE_MIN_PX);
  return (
    <svg
      xmlns={SVG_NS}
      width={(w * height) / h}
      height={height}
      viewBox={`${-WM.pad} ${WM.top} ${w} ${h}`}
      role="img"
      aria-label="puls3 wordmark"
    >
      <WordmarkGlyphs opt={halftone ? LOGO_HALFTONE : LOGO_SOLID} p={palette} />
    </svg>
  );
};

/** Wordmark height (px) at which the "3" reaches the halftone threshold. */
export const WORDMARK_HALFTONE_MIN_PX = Math.ceil(
  (THREE_HALFTONE_MIN_PX * (WM.bottom - WM.top)) / THREE_UNITS,
);
