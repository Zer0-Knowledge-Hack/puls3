import React from "react";
import type { Palette } from "../tokens";

/** Shapes of the generated outline data (1000 units per em, y down, baseline at 0). */
export type GlyphItem = {
  char: string;
  x: number;
  adv: number;
  d: string;
  bbox: number[]; // [minX, minY, maxX, maxY]
  contours?: number[][][];
};

export type GlyphFont = {
  family: string;
  weight: number;
  ascender: number;
  descender: number;
  capHeight: number;
  xHeight: number;
  layouts: Record<string, { width: number; glyphs: GlyphItem[] }>;
};

export type Placed = GlyphItem & { dx: number };

/** Applies tracking (em units * 1000) to a laid-out string. */
export const placeGlyphs = (
  font: GlyphFont,
  text: "puls3" | "PULS3",
  tracking = 0,
) => {
  const layout = font.layouts[text];
  const glyphs: Placed[] = layout.glyphs.map((g, i) => ({
    ...g,
    dx: i * tracking,
  }));
  const width = layout.width + tracking * (glyphs.length - 1);
  return { glyphs, width };
};

/** Nonzero-winding point-in-glyph test on flattened contours. */
export const insideGlyph = (contours: number[][][], x: number, y: number) => {
  let winding = 0;
  for (const poly of contours) {
    for (let i = 0; i < poly.length; i++) {
      const [x1, y1] = poly[i];
      const [x2, y2] = poly[(i + 1) % poly.length];
      if (y1 <= y) {
        if (y2 > y && (x2 - x1) * (y - y1) - (x - x1) * (y2 - y1) > 0)
          winding++;
      } else if (y2 <= y && (x2 - x1) * (y - y1) - (x - x1) * (y2 - y1) < 0) {
        winding--;
      }
    }
  }
  return winding !== 0;
};

/** Samples a glyph into a square dot grid (grid anchored to the wordmark, not the glyph). */
export const sampleGlyph = (g: GlyphItem, step: number) => {
  const dots: { x: number; y: number }[] = [];
  if (!g.contours) return dots;
  const [x0, y0, x1, y1] = g.bbox;
  const gx0 = Math.floor(x0 / step) * step + step / 2;
  const gy0 = Math.floor(y0 / step) * step + step / 2;
  for (let y = gy0; y <= y1; y += step) {
    for (let x = gx0; x <= x1; x += step) {
      if (insideGlyph(g.contours, x, y)) dots.push({ x, y });
    }
  }
  return dots;
};

/** Renders outlined glyphs; the "3" can take the accent color. */
export const OutlineText: React.FC<{
  font: GlyphFont;
  text: "puls3" | "PULS3";
  tracking?: number;
  p: Palette;
  accentThree?: boolean;
  skip?: (g: Placed, i: number) => boolean;
}> = ({ font, text, tracking = 0, p, accentThree = true, skip }) => {
  const { glyphs } = placeGlyphs(font, text, tracking);
  return (
    <g>
      {glyphs.map((g, i) =>
        skip?.(g, i) ? null : (
          <path
            key={i}
            d={g.d}
            transform={g.dx ? `translate(${g.dx} 0)` : undefined}
            fill={accentThree && g.char === "3" ? p.accent : p.ink}
          />
        ),
      )}
    </g>
  );
};
