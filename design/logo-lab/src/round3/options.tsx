import React from "react";
import type { Palette } from "../tokens";
import { easeOutCubic, segment } from "../lib/geometry";
import { GLYPH_FONTS } from "./generated/glyphs";
import {
  placeGlyphs,
  sampleGlyph,
  type GlyphFont,
  type GlyphItem,
  type Placed,
} from "./outline";

export type GlyphKey = keyof typeof GLYPH_FONTS;
export type Direction = "A" | "B" | "C" | "D";

/** Context passed to special renderers (all coordinates in font units: 1000/em, baseline 0). */
export type RenderCtx = {
  font: GlyphFont;
  glyphs: Placed[];
  width: number;
  p: Palette;
  t: number; // 0..1 wordmark reveal
  from?: { x: number; y: number }; // pulse origin for "assemble" reveals (font units)
};

export type Option3 = {
  id: string;
  dir: Direction;
  font: string; // display name
  weight: string;
  treatment: string;
  note: string; // why it works (or not)
  glyphKey: GlyphKey;
  text: "puls3" | "PULS3";
  tracking: number; // em
  /** Live text rendering via @remotion/google-fonts (solid options only). */
  live?: { family: string; weight: number };
  /** Custom renderer; solid outlined glyphs when omitted. */
  render?: (ctx: RenderCtx) => React.ReactNode;
};

export const fontOf = (o: Option3): GlyphFont =>
  GLYPH_FONTS[o.glyphKey] as GlyphFont;

export const layoutOf = (o: Option3) =>
  placeGlyphs(fontOf(o), o.text, o.tracking * 1000);

const stack = (family: string) =>
  `'${family}', 'Helvetica Neue', Arial, sans-serif`;
export const liveFamily = (o: Option3) =>
  o.live ? stack(o.live.family) : undefined;

/* ------------------------------------------------------------------ */
/* Shared glyph helpers                                                */
/* ------------------------------------------------------------------ */

const area = (poly: number[][]) => {
  let a = 0;
  for (let i = 0; i < poly.length; i++) {
    const [x1, y1] = poly[i];
    const [x2, y2] = poly[(i + 1) % poly.length];
    a += x1 * y2 - x2 * y1;
  }
  return Math.abs(a / 2);
};

const bboxOf = (poly: number[][]) => {
  const xs = poly.map((q) => q[0]);
  const ys = poly.map((q) => q[1]);
  return {
    x0: Math.min(...xs),
    y0: Math.min(...ys),
    x1: Math.max(...xs),
    y1: Math.max(...ys),
  };
};

/** The counter of a glyph: its smallest contour (a hole), in glyph-local font units. */
const counterOf = (g: GlyphItem) => {
  const cs = (g.contours ?? []).filter((c) => c.length > 2);
  if (cs.length < 2) return null;
  // The largest contour is the outline itself; the next one is the counter (hole).
  const sorted = [...cs].sort((a, b) => area(b) - area(a));
  const b = bboxOf(sorted[1]);
  return {
    cx: (b.x0 + b.x1) / 2,
    cy: (b.y0 + b.y1) / 2,
    w: b.x1 - b.x0,
    h: b.y1 - b.y0,
  };
};

/** Solid glyph paths (tracking applied through dx). */
const Solid: React.FC<{
  glyphs: Placed[];
  p: Palette;
  t: number;
  accentThree?: boolean;
  skip?: (g: Placed) => boolean;
}> = ({ glyphs, p, t, accentThree = true, skip }) => (
  <g>
    {glyphs.map((g, i) => {
      if (skip?.(g)) return null;
      // Letters resolve one after another with a small rise.
      const k = easeOutCubic(segment(t, i * 0.1, i * 0.1 + 0.6));
      if (k <= 0) return null;
      return (
        <path
          key={i}
          d={g.d}
          opacity={k}
          transform={`translate(${g.dx} ${(1 - k) * 60})`}
          fill={accentThree && g.char === "3" ? p.accent : p.ink}
        />
      );
    })}
  </g>
);

export const SolidRender = (ctx: RenderCtx) => (
  <Solid glyphs={ctx.glyphs} p={ctx.p} t={ctx.t} />
);

/** Dots that fly in from the pulse origin to their final position. */
const assemble = (
  x: number,
  y: number,
  ctx: RenderCtx,
  order: number, // 0..1, used to stagger
) => {
  const k = easeOutCubic(segment(ctx.t, order * 0.45, order * 0.45 + 0.55));
  const o = ctx.from ?? { x, y };
  return { x: o.x + (x - o.x) * k, y: o.y + (y - o.y) * k, k };
};

/* ------------------------------------------------------------------ */
/* Direction A: halftone / dot matrix                                  */
/* ------------------------------------------------------------------ */

/** A2: the whole wordmark resampled into dots that grow toward the "3" like a pulse. */
const halftoneWordmark =
  (step: number) =>
  (ctx: RenderCtx): React.ReactNode => {
    const dots: React.ReactNode[] = [];
    ctx.glyphs.forEach((g, gi) => {
      const pts = sampleGlyph(g, step);
      pts.forEach((q, qi) => {
        const x = q.x + g.dx;
        const prog = x / ctx.width; // 0 at "p", 1 at "3"
        const r = step * 0.5 * (0.5 + 0.42 * prog);
        const a = assemble(x, q.y, ctx, prog);
        dots.push(
          <circle
            key={`${gi}-${qi}`}
            cx={a.x.toFixed(1)}
            cy={a.y.toFixed(1)}
            r={(r * (0.3 + 0.7 * a.k)).toFixed(1)}
            fill={g.char === "3" ? ctx.p.accent : ctx.p.ink}
            opacity={a.k}
          />,
        );
      });
    });
    return <g>{dots}</g>;
  };

/** A3: solid letters; only the "3" is halftone, dots swelling toward its center (C01 logic). */
const halftoneThree =
  (step: number) =>
  (ctx: RenderCtx): React.ReactNode => {
    const three = ctx.glyphs.find((g) => g.char === "3");
    if (!three) return null;
    const [x0, y0, x1, y1] = three.bbox;
    const cx = (x0 + x1) / 2;
    const cy = (y0 + y1) / 2;
    const R = Math.hypot(x1 - x0, y1 - y0) / 2;
    return (
      <g>
        <Solid
          glyphs={ctx.glyphs}
          p={ctx.p}
          t={ctx.t}
          skip={(g) => g.char === "3"}
        />
        {sampleGlyph(three, step).map((q, i) => {
          const d = Math.hypot(q.x - cx, q.y - cy) / R;
          const r = step * 0.5 * (0.62 + 0.36 * (1 - d));
          const a = assemble(q.x + three.dx, q.y, ctx, 0.35 + 0.3 * d);
          return (
            <circle
              key={i}
              cx={a.x.toFixed(1)}
              cy={a.y.toFixed(1)}
              r={(r * a.k).toFixed(1)}
              fill={d < 0.62 ? ctx.p.accent : ctx.p.secondary}
            />
          );
        })}
      </g>
    );
  };

/** Doto is already a dot-matrix face: color the "3" dots amber-to-lavender from its center. */
const dotoPulse = (ctx: RenderCtx): React.ReactNode => {
  const three = ctx.glyphs.find((g) => g.char === "3");
  return (
    <g>
      <Solid
        glyphs={ctx.glyphs}
        p={ctx.p}
        t={ctx.t}
        skip={(g) => g.char === "3"}
      />
      {three
        ? (() => {
            const [x0, y0, x1, y1] = three.bbox;
            const cx = (x0 + x1) / 2;
            const cy = (y0 + y1) / 2;
            const R = Math.hypot(x1 - x0, y1 - y0) / 2;
            return (three.contours ?? []).map((c, i) => {
              const b = bboxOf(c);
              const d =
                Math.hypot((b.x0 + b.x1) / 2 - cx, (b.y0 + b.y1) / 2 - cy) / R;
              const k = easeOutCubic(
                segment(ctx.t, 0.4 + 0.3 * d, 0.7 + 0.3 * d),
              );
              const pts = c
                .map(
                  (q) => `${(q[0] + three.dx).toFixed(1)},${q[1].toFixed(1)}`,
                )
                .join(" ");
              return (
                <polygon
                  key={i}
                  points={pts}
                  opacity={k}
                  fill={d < 0.55 ? ctx.p.accent : ctx.p.secondary}
                />
              );
            });
          })()
        : null}
    </g>
  );
};

/* ------------------------------------------------------------------ */
/* Direction D: custom cuts                                            */
/* ------------------------------------------------------------------ */

/** Mini C01 inside the counter of the "p": amber core plus a ring of lavender dots. */
const MiniPulse: React.FC<{
  cx: number;
  cy: number;
  R: number;
  p: Palette;
  k: number;
}> = ({ cx, cy, R, p, k }) => (
  <g>
    <circle cx={cx} cy={cy} r={R * 0.34 * k} fill={p.accent} />
    {Array.from({ length: 8 }).map((_, i) => {
      const a = (i * Math.PI) / 4 + Math.PI / 8;
      const kk = easeOutCubic(segment(k, 0.3, 1));
      return (
        <circle
          key={i}
          cx={(cx + Math.cos(a) * R * 0.74 * kk).toFixed(1)}
          cy={(cy + Math.sin(a) * R * 0.74 * kk).toFixed(1)}
          r={(R * 0.14 * kk).toFixed(1)}
          fill={p.secondary}
        />
      );
    })}
  </g>
);

/** D: the counter of the "p" becomes a mini C01 halftone pulse. */
const pulseCounter = (ctx: RenderCtx): React.ReactNode => {
  const pg = ctx.glyphs.find((g) => g.char.toLowerCase() === "p");
  const c = pg ? counterOf(pg) : null;
  const k = easeOutCubic(segment(ctx.t, 0.55, 1));
  return (
    <g>
      <Solid glyphs={ctx.glyphs} p={ctx.p} t={ctx.t} />
      {pg && c ? (
        <MiniPulse
          cx={c.cx + pg.dx}
          cy={c.cy}
          R={Math.min(c.w, c.h) * 0.46}
          p={ctx.p}
          k={k}
        />
      ) : null}
    </g>
  );
};

/** D: the upper terminal of the "3" ends in an amber signal dot (a satellite starting its orbit). */
const signalThree =
  (dotScale: number) =>
  (ctx: RenderCtx): React.ReactNode => {
    const three = ctx.glyphs.find((g) => g.char === "3");
    const k = easeOutCubic(segment(ctx.t, 0.6, 1));
    let dot: React.ReactNode = null;
    if (three?.contours?.length) {
      const outer = [...three.contours].sort((a, b) => area(b) - area(a))[0];
      const [x0, y0, x1, y1] = three.bbox;
      const midY = (y0 + y1) / 2;
      // Upper-left extreme of the outline = the tip of the upper terminal.
      const upper = outer.filter((q) => q[1] < midY - (y1 - y0) * 0.12);
      const tip = upper.reduce(
        (best, q) => (q[0] + q[1] * 0.35 < best[0] + best[1] * 0.35 ? q : best),
        upper[0],
      );
      const r = (x1 - x0) * dotScale;
      dot = (
        <circle
          cx={tip[0] + three.dx - r * 0.9}
          cy={tip[1] + r * 0.2}
          r={r * k}
          fill={ctx.p.accent}
        />
      );
    }
    return (
      <g>
        <Solid glyphs={ctx.glyphs} p={ctx.p} t={ctx.t} accentThree={false} />
        {dot}
      </g>
    );
  };

/* ------------------------------------------------------------------ */
/* The option catalog                                                  */
/* ------------------------------------------------------------------ */

export const OPTIONS: Option3[] = [
  // A: halftone / dot matrix
  {
    id: "A1a",
    dir: "A",
    font: "Doto",
    weight: "500 · ROND 100",
    treatment: "A1 dot-matrix with round dots, lowercase",
    note: "Speaks the mark's dot language natively; 500 gets thin at 24 px.",
    glyphKey: "DotoRound500",
    text: "puls3",
    tracking: 0,
  },
  {
    id: "A1b",
    dir: "A",
    font: "Doto",
    weight: "900 · ROND 100",
    treatment: "A1 dot-matrix with round dots, pulse-colored 3",
    note: "Heavy dots hold up small; the 3 inherits C01's amber-to-lavender falloff.",
    glyphKey: "DotoRound900",
    text: "puls3",
    tracking: 0,
    render: dotoPulse,
  },
  {
    id: "A2a",
    dir: "A",
    font: "Unbounded",
    weight: "700",
    treatment: "A2 resampled into halftone dots, growing toward the 3",
    note: "The wordmark literally pulses left to right; needs size to resolve.",
    glyphKey: "Unbounded700",
    text: "puls3",
    tracking: 0.02,
    render: halftoneWordmark(62),
  },
  {
    id: "A2b",
    dir: "A",
    font: "Sora",
    weight: "700",
    treatment: "A2 resampled into halftone dots, growing toward the 3",
    note: "Narrower Sora loses its bowls in the dot grid; Unbounded wins.",
    glyphKey: "Sora700",
    text: "puls3",
    tracking: 0.02,
    render: halftoneWordmark(58),
  },
  {
    id: "A3a",
    dir: "A",
    font: "Sora",
    weight: "600",
    treatment: "A3 solid wordmark, halftone 3",
    note: "Clean and legible; only the 3 carries the pulse texture.",
    glyphKey: "Sora600",
    text: "puls3",
    tracking: -0.01,
    render: halftoneThree(50),
  },
  {
    id: "A3b",
    dir: "A",
    font: "Unbounded",
    weight: "700",
    treatment: "A3 solid wordmark, halftone 3",
    note: "Wider, rounder host for the halftone 3; strong at every size.",
    glyphKey: "Unbounded700",
    text: "puls3",
    tracking: 0,
    render: halftoneThree(56),
  },

  // B: space age
  {
    id: "B1",
    dir: "B",
    font: "Tektur",
    weight: "500",
    treatment: "B lowercase",
    note: "Chamfered mission hardware; slightly military.",
    glyphKey: "Tektur500",
    text: "puls3",
    tracking: 0.01,
    live: { family: "Tektur", weight: 500 },
  },
  {
    id: "B2",
    dir: "B",
    font: "Zen Dots",
    weight: "400",
    treatment: "B lowercase",
    note: "Rounded 70s space-age display; friendly, very retro.",
    glyphKey: "ZenDots400",
    text: "puls3",
    tracking: 0,
    live: { family: "Zen Dots", weight: 400 },
  },
  {
    id: "B3",
    dir: "B",
    font: "Audiowide",
    weight: "400",
    treatment: "B lowercase",
    note: "Streamlined and fast, but reads as racing/gaming.",
    glyphKey: "Audiowide400",
    text: "puls3",
    tracking: 0,
    live: { family: "Audiowide", weight: 400 },
  },
  {
    id: "B4",
    dir: "B",
    font: "Quantico",
    weight: "700",
    treatment: "B UPPERCASE tracked",
    note: "Squared instrument lettering; strong in caps, stiff in lowercase.",
    glyphKey: "Quantico700",
    text: "PULS3",
    tracking: 0.12,
    live: { family: "Quantico", weight: 700 },
  },
  {
    id: "B5",
    dir: "B",
    font: "Electrolize",
    weight: "400",
    treatment: "B UPPERCASE tracked (extra pick)",
    note: "Aerospace signage over arcade: picked over Aldrich, Oxanium, Chakra Petch.",
    glyphKey: "Electrolize400",
    text: "PULS3",
    tracking: 0.16,
    live: { family: "Electrolize", weight: 400 },
  },

  // C: thin and extended (telemetry)
  ...(
    [
      ["C1", "Michroma", "400", "Michroma400", 0.0, 0.14, "Michroma"],
      ["C2", "Unbounded", "300 / 200", "Unbounded300", 0.0, 0.18, "Unbounded"],
      ["C3", "Lexend Giga", "300", "LexendGiga300", 0.0, 0.08, "Lexend Giga"],
      ["C4", "Syncopate", "400", "Syncopate400", 0.04, 0.3, "Syncopate"],
    ] as const
  ).flatMap(([id, font, weight, key, trLower, trUpper, family]) => {
    const upperKey: GlyphKey = key === "Unbounded300" ? "Unbounded200" : key;
    const liveWeight = key === "Unbounded300" ? 300 : Number(weight);
    const notes: Record<string, [string, string]> = {
      C1: [
        "Extended and precise; telemetry-panel calm.",
        "Wide caps feel like a mission callsign.",
      ],
      C2: [
        "Light, wide, soft: the most weightless option.",
        "ExtraLight caps: elegant, fragile at 24 px.",
      ],
      C3: [
        "Airy geometric; spacing does the work.",
        "Very spread caps; loses cohesion as a mark.",
      ],
      C4: [
        "Syncopate lowercase is small caps; stately.",
        "Maximum tracking: pure telemetry readout.",
      ],
    };
    return [
      {
        id: `${id}a`,
        dir: "C" as const,
        font,
        weight: key === "Unbounded300" ? "300" : weight,
        treatment: "C lowercase",
        note: notes[id][0],
        glyphKey: key as GlyphKey,
        text: "puls3" as const,
        tracking: trLower,
        live: { family, weight: liveWeight },
      },
      {
        id: `${id}b`,
        dir: "C" as const,
        font,
        weight: key === "Unbounded300" ? "200" : weight,
        treatment: "C UPPERCASE tracked",
        note: notes[id][1],
        glyphKey: upperKey,
        text: "PULS3" as const,
        tracking: trUpper,
        live: { family, weight: key === "Unbounded300" ? 200 : liveWeight },
      },
    ];
  }),

  // D: custom cuts (outlined)
  {
    id: "D1",
    dir: "D",
    font: "Unbounded",
    weight: "300",
    treatment: "D1 p-counter becomes a mini C01 pulse",
    note: "Mark and wordmark share one idea; the p carries the heartbeat.",
    glyphKey: "Unbounded300",
    text: "puls3",
    tracking: 0,
    render: pulseCounter,
  },
  {
    id: "D2",
    dir: "D",
    font: "Unbounded",
    weight: "300",
    treatment: "D2 the 3's upper terminal ends in an amber signal dot",
    note: "Quiet, ownable detail; the dot echoes C01's amber core.",
    glyphKey: "Unbounded300",
    text: "puls3",
    tracking: 0.03,
    render: signalThree(0.14),
  },
  {
    id: "D3",
    dir: "D",
    font: "Doto",
    weight: "900 · ROND 100",
    treatment: "D3 round dot-matrix, amber pulse dot in the p counter",
    note: "Pure dot language; an amber pulse dot sits in the p's counter.",
    glyphKey: "DotoRound900",
    text: "puls3",
    tracking: 0,
    render: (ctx) => (
      <g>
        {dotoPulse(ctx)}
        {(() => {
          const pg = ctx.glyphs.find((g) => g.char === "p");
          if (!pg) return null;
          const [x0, , x1] = pg.bbox;
          const xh = ctx.font.xHeight;
          const k = easeOutCubic(segment(ctx.t, 0.55, 1));
          return (
            <circle
              cx={x0 + (x1 - x0) * 0.6}
              cy={-xh / 2}
              r={(x1 - x0) * 0.1 * k}
              fill={ctx.p.accent}
            />
          );
        })()}
      </g>
    ),
  },
  {
    id: "D4",
    dir: "D",
    font: "Michroma",
    weight: "400",
    treatment: "D4 Michroma with a mini C01 pulse in the p counter",
    note: "Telemetry extended type plus the heartbeat; wide counter fits the pulse.",
    glyphKey: "Michroma400",
    text: "puls3",
    tracking: 0,
    render: pulseCounter,
  },
];

export const option = (id: string) =>
  OPTIONS.find((o) => o.id === id) ?? OPTIONS[0];
export const optionsOf = (dir: Direction) =>
  OPTIONS.filter((o) => o.dir === dir);
