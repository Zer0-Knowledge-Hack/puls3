import React from "react";
import type { Palette } from "../tokens";
import {
  arcPath,
  drawOn,
  easeInOutCubic,
  easeOutCubic,
  polar,
  segment,
} from "../lib/geometry";
import type { ArtProps } from "../concepts/types";
import {
  hexDisc,
  hexFlower,
  lambert,
  ringDisc,
  sweepLight,
  type Vec3,
} from "./halftone";

/* ------------------------------------------------------------------ */
/* Shared building blocks                                              */
/* ------------------------------------------------------------------ */

const f2 = (n: number) => n.toFixed(2);

/** A halftone sphere: dot size follows Lambert shading; the dark side keeps faint "earthshine" dots. */
const Planet: React.FC<{
  cx: number;
  cy: number;
  R: number;
  step: number;
  maxR: number;
  L: Vec3;
  p: Palette;
  ghostR: number;
  appear?: number;
}> = ({ cx, cy, R, step, maxR, L, p, ghostR, appear = 1 }) => (
  <g>
    {ringDisc(cx, cy, R, step).map((dot, i) => {
      const k = easeOutCubic(segment(appear, dot.d * 0.4, dot.d * 0.4 + 0.6));
      const I = lambert(dot.u * 0.98, dot.v * 0.98, L);
      const lit = I > 0.04;
      const r =
        (lit
          ? Math.max(ghostR, maxR * (0.18 + 0.82 * Math.pow(I, 0.85)))
          : ghostR) * k;
      if (r <= 0.05) return null;
      return (
        <circle
          key={i}
          cx={f2(dot.x)}
          cy={f2(dot.y)}
          r={f2(r)}
          fill={I > 0.55 ? p.accent : p.secondary}
          opacity={lit ? 1 : 0.55}
        />
      );
    })}
  </g>
);

/** C01-style radial halftone core: dots swell toward an amber center. */
const PulseCore: React.FC<{
  cx: number;
  cy: number;
  R: number;
  step: number;
  minR: number;
  maxR: number;
  p: Palette;
  t: number;
}> = ({ cx, cy, R, step, minR, maxR, p, t }) => (
  <g>
    {hexDisc(cx, cy, R, step).map((dot, i) => {
      const k = easeOutCubic(segment(t, dot.d * 0.5, dot.d * 0.5 + 0.5));
      const r = (minR + (maxR - minR) * Math.pow(1 - dot.d, 1.1)) * k;
      if (r <= 0.05) return null;
      return (
        <circle
          key={i}
          cx={f2(dot.x)}
          cy={f2(dot.y)}
          r={f2(r)}
          fill={dot.d < 0.62 ? p.accent : p.secondary}
        />
      );
    })}
  </g>
);

/** 7-dot flower core for small sizes. */
const FlowerCore: React.FC<{
  cx: number;
  cy: number;
  dist: number;
  centerR: number;
  petalR: number;
  p: Palette;
  t: number;
}> = ({ cx, cy, dist, centerR, petalR, p, t }) => (
  <g>
    {hexFlower(cx, cy, dist).map((d, i) => {
      const k = easeOutCubic(
        segment(t, d.center ? 0 : 0.2, d.center ? 0.5 : 0.8),
      );
      return (
        <circle
          key={i}
          cx={f2(d.x)}
          cy={f2(d.y)}
          r={f2((d.center ? centerR : petalR) * k)}
          fill={d.center ? p.accent : p.secondary}
        />
      );
    })}
  </g>
);

type RingSpec = {
  r: number;
  width: number;
  arcs: [number, number][];
  tone: "ink" | "secondary";
};

/** Broken concentric rings that emit outward as `t` grows. */
const Rings: React.FC<{
  cx: number;
  cy: number;
  rings: RingSpec[];
  p: Palette;
  t: number;
}> = ({ cx, cy, rings, p, t }) => (
  <g>
    {rings.map((ring, i) => {
      const k = easeOutCubic(segment(t, i * 0.25, 0.6 + i * 0.25));
      if (k <= 0) return null;
      const r = ring.r * (0.6 + 0.4 * k);
      return (
        <g key={i} opacity={k}>
          {ring.arcs.map(([a, b], j) => (
            <path
              key={j}
              d={arcPath(cx, cy, r, r, a, b)}
              fill="none"
              stroke={ring.tone === "ink" ? p.ink : p.secondary}
              strokeWidth={ring.width}
              strokeLinecap="round"
            />
          ))}
        </g>
      );
    })}
  </g>
);

/** Arcs covering a full ring minus gaps centered at the given angles. */
const gapped = (gapCenters: number[], gapWidth: number): [number, number][] => {
  const sorted = [...gapCenters].sort((a, b) => a - b);
  return sorted.map((g, i) => {
    const next = i === sorted.length - 1 ? sorted[0] + 360 : sorted[i + 1];
    return [g + gapWidth / 2, next - gapWidth / 2];
  });
};

const Stem: React.FC<{
  x: number;
  y0: number;
  y1: number;
  w: number;
  p: Palette;
  t: number;
}> = ({ x, y0, y1, w, p, t }) => (
  <path
    d={`M ${x} ${y0} L ${x} ${y1}`}
    stroke={p.ink}
    strokeWidth={w}
    strokeLinecap="round"
    fill="none"
    {...drawOn(t)}
  />
);

/* ------------------------------------------------------------------ */
/* R01 Halftone Planet                                                 */
/* ------------------------------------------------------------------ */

export const R01Art: React.FC<ArtProps> = ({ t, p }) => (
  <Planet
    cx={64}
    cy={64}
    R={56}
    step={7.4}
    maxR={3.6}
    ghostR={0.9}
    L={sweepLight(easeInOutCubic(segment(t, 0.15, 1)))}
    appear={segment(t, 0, 0.45)}
    p={p}
  />
);

export const R01Small: React.FC<ArtProps> = ({ t, p }) => (
  <Planet
    cx={64}
    cy={64}
    R={56}
    step={14}
    maxR={6.8}
    ghostR={2.2}
    L={sweepLight(easeInOutCubic(segment(t, 0.15, 1)))}
    appear={segment(t, 0, 0.45)}
    p={p}
  />
);

/* ------------------------------------------------------------------ */
/* R02 Halftone Pulse + Ring                                           */
/* ------------------------------------------------------------------ */

const R02_RING = (width: number): RingSpec[] => [
  { r: 52, width, arcs: gapped([330, 190], 34), tone: "secondary" },
];

export const R02Art: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    <PulseCore
      cx={64}
      cy={64}
      R={36}
      step={7.2}
      minR={1}
      maxR={3.5}
      p={p}
      t={segment(t, 0, 0.6)}
    />
    <Rings cx={64} cy={64} rings={R02_RING(6)} p={p} t={segment(t, 0.4, 1)} />
  </g>
);

export const R02Small: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    <PulseCore
      cx={64}
      cy={64}
      R={36}
      step={12.5}
      minR={2.6}
      maxR={6.2}
      p={p}
      t={segment(t, 0, 0.6)}
    />
    <Rings cx={64} cy={64} rings={R02_RING(9)} p={p} t={segment(t, 0.4, 1)} />
  </g>
);

/* ------------------------------------------------------------------ */
/* R03 Eclipse Pulse                                                   */
/* ------------------------------------------------------------------ */

const Eclipse: React.FC<ArtProps & { small: boolean }> = ({ t, p, small }) => {
  const maskId = `eclipse-${React.useId().replace(/:/g, "")}`;
  const slide = easeInOutCubic(segment(t, 0.1, 0.7));
  const sun = { cx: 64, cy: 64, r: 52 };
  // The moon slides from concentric (no rim) to offset (a crescent of light at the upper right).
  const off = (small ? 7 : 5) * slide;
  const moon = { cx: 64 - off, cy: 64 + off, r: small ? 47 : 49 };
  const flare = segment(t, 0.55, 1);
  const discDots = ringDisc(
    moon.cx,
    moon.cy,
    moon.r - (small ? 9 : 6),
    small ? 12 : 6.6,
  );
  return (
    <g>
      <defs>
        <mask id={maskId}>
          <circle cx={sun.cx} cy={sun.cy} r={sun.r} fill="white" />
          <circle cx={moon.cx} cy={moon.cy} r={moon.r} fill="black" />
        </mask>
      </defs>
      <circle
        cx={sun.cx}
        cy={sun.cy}
        r={sun.r}
        fill={p.accent}
        mask={`url(#${maskId})`}
      />
      {/* The dark disc, rendered as fine halftone that thickens toward the limb. */}
      {discDots.map((d, i) => {
        const k = easeOutCubic(segment(t, 0, 0.5));
        const r = (small ? 2.1 + 1.6 * d.d : 0.7 + 1.9 * d.d * d.d) * k;
        return (
          <circle
            key={i}
            cx={f2(d.x)}
            cy={f2(d.y)}
            r={f2(r)}
            fill={p.secondary}
          />
        );
      })}
      {/* Corona: halftone flare beyond the bright limb. */}
      {flare > 0
        ? Array.from({ length: small ? 5 : 9 }).map((_, i) => {
            const n = small ? 5 : 9;
            const ang = -100 + (i * 110) / (n - 1);
            return [1, 2].map((k) => {
              const q = polar(
                sun.cx,
                sun.cy,
                sun.r + (small ? 7 : 5) * k,
                sun.r + (small ? 7 : 5) * k,
                ang,
              );
              const falloff = 1 - Math.abs(ang + 45) / 60;
              const r =
                (small ? 3.2 : 1.9) *
                (k === 1 ? 1 : 0.55) *
                Math.max(0.35, falloff) *
                flare;
              return (
                <circle
                  key={`${i}-${k}`}
                  cx={f2(q.x)}
                  cy={f2(q.y)}
                  r={f2(r)}
                  fill={p.accent}
                />
              );
            });
          })
        : null}
    </g>
  );
};

export const R03Art: React.FC<ArtProps> = (props) => (
  <Eclipse {...props} small={false} />
);
export const R03Small: React.FC<ArtProps> = (props) => (
  <Eclipse {...props} small />
);

/* ------------------------------------------------------------------ */
/* R04 Signal Rings v2                                                 */
/* ------------------------------------------------------------------ */

// Gaps are rotationally offset by 60deg between rings, so they never line up into a band.
const R04_RINGS = (w: number): RingSpec[] => [
  { r: 35, width: w, arcs: gapped([90, 210, 330], 36), tone: "ink" },
  { r: 54, width: w, arcs: gapped([30, 150, 270], 26), tone: "secondary" },
];

export const R04Art: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    <PulseCore
      cx={64}
      cy={64}
      R={20}
      step={6.2}
      minR={1.1}
      maxR={3.1}
      p={p}
      t={segment(t, 0, 0.45)}
    />
    <Rings cx={64} cy={64} rings={R04_RINGS(7)} p={p} t={segment(t, 0.25, 1)} />
  </g>
);

export const R04Small: React.FC<ArtProps> = ({ t, p }) => (
  <g>
    <FlowerCore
      cx={64}
      cy={64}
      dist={12}
      centerR={7}
      petalR={4.2}
      p={p}
      t={segment(t, 0, 0.45)}
    />
    <Rings
      cx={64}
      cy={64}
      rings={R04_RINGS(9.5)}
      p={p}
      t={segment(t, 0.25, 1)}
    />
  </g>
);

/* ------------------------------------------------------------------ */
/* R05 Pulse Orbit                                                     */
/* ------------------------------------------------------------------ */

// One tilted ellipse that fully encloses the core: it never crosses the circle,
// and there is only one curve (no parallel lines), so it cannot read as the Stellar monogram.
const ORBIT = { rx: 58, ry: 31, tilt: -16, sat: 300 };

const PulseOrbit: React.FC<ArtProps & { small: boolean }> = ({
  t,
  p,
  small,
}) => {
  const draw = easeInOutCubic(segment(t, 0.3, 1));
  const start = ORBIT.sat - 340; // the arc ends at the satellite, leaving a short gap behind it
  const end = start + 320 * draw;
  const tip = polar(64, 64, ORBIT.rx, ORBIT.ry, end);
  return (
    <g>
      {small ? (
        <FlowerCore
          cx={64}
          cy={64}
          dist={11}
          centerR={6.5}
          petalR={4.4}
          p={p}
          t={segment(t, 0, 0.45)}
        />
      ) : (
        <PulseCore
          cx={64}
          cy={64}
          R={23}
          step={6.3}
          minR={1.1}
          maxR={3.2}
          p={p}
          t={segment(t, 0, 0.45)}
        />
      )}
      {draw > 0 ? (
        <g transform={`rotate(${ORBIT.tilt} 64 64)`}>
          <path
            d={arcPath(64, 64, ORBIT.rx, ORBIT.ry, start, end)}
            fill="none"
            stroke={p.ink}
            strokeWidth={small ? 7 : 4.5}
            strokeLinecap="round"
          />
          <circle
            cx={f2(tip.x)}
            cy={f2(tip.y)}
            r={small ? 10 : 7.5}
            fill={p.accent}
          />
        </g>
      ) : null}
    </g>
  );
};

export const R05Art: React.FC<ArtProps> = (props) => (
  <PulseOrbit {...props} small={false} />
);
export const R05Small: React.FC<ArtProps> = (props) => (
  <PulseOrbit {...props} small />
);

/* ------------------------------------------------------------------ */
/* R06 Halftone p v2                                                   */
/* ------------------------------------------------------------------ */

type PDot = { x: number; y: number };

/** Dots arranged along the p: stem columns plus concentric bowl rings (clean round silhouette). */
const pDots = (small: boolean) => {
  const bowl = { cx: 74, cy: 52 };
  const dots: PDot[] = [];
  const stemXs = small ? [34] : [26, 38];
  const stepY = small ? 13.5 : 12;
  for (const x of stemXs) {
    for (let y = 22; y <= 118; y += stepY) dots.push({ x, y });
  }
  const rings = small
    ? [{ r: 30, n: 14 }]
    : [
        { r: 24, n: 12 },
        { r: 36, n: 18 },
      ];
  const minX = small ? 44 : 46;
  for (const { r, n } of rings) {
    for (let i = 0; i < n; i++) {
      const a = (i * 2 * Math.PI) / n - Math.PI / 2;
      const x = bowl.cx + Math.cos(a) * r;
      const y = bowl.cy + Math.sin(a) * r;
      if (x >= minX) dots.push({ x, y });
    }
  }
  return { dots, bowl };
};

const HalftoneP2: React.FC<ArtProps & { small: boolean }> = ({
  t,
  p,
  small,
}) => {
  const { dots, bowl } = pDots(small);
  const pulse = easeOutCubic(segment(t, 0.55, 0.85));
  const echo = segment(t, 0.7, 1);
  return (
    <g>
      {dots.map((d, i) => {
        const v = (d.y - 16) / 104; // 0 at top, 1 at bottom
        const k = easeOutCubic(segment(t, v * 0.45, v * 0.45 + 0.35));
        const r = (small ? 6.4 - 1.2 * v : 5.3 - 1.7 * v) * k;
        return (
          <circle key={i} cx={f2(d.x)} cy={f2(d.y)} r={f2(r)} fill={p.ink} />
        );
      })}
      {echo > 0 && echo < 1 ? (
        <circle
          cx={bowl.cx}
          cy={bowl.cy}
          r={10 + echo * 8}
          fill="none"
          stroke={p.accent}
          strokeWidth={2}
          opacity={1 - echo}
        />
      ) : null}
      <circle
        cx={bowl.cx}
        cy={bowl.cy}
        r={(small ? 12 : 10) * pulse}
        fill={p.accent}
      />
    </g>
  );
};

export const R06Art: React.FC<ArtProps> = (props) => (
  <HalftoneP2 {...props} small={false} />
);
export const R06Small: React.FC<ArtProps> = (props) => (
  <HalftoneP2 {...props} small />
);

/* ------------------------------------------------------------------ */
/* R07 p Signal                                                        */
/* ------------------------------------------------------------------ */

const PSignal: React.FC<ArtProps & { small: boolean }> = ({ t, p, small }) => {
  const node = easeOutCubic(segment(t, 0.3, 0.55));
  const rings: RingSpec[] = [
    {
      r: 18,
      width: small ? 8 : 6.5,
      arcs: gapped([200], 70),
      tone: "secondary",
    },
    { r: 34, width: small ? 11 : 9, arcs: gapped([25], 34), tone: "ink" },
  ];
  return (
    <g>
      <Stem
        x={30}
        y0={22}
        y1={118}
        w={small ? 14 : 12}
        p={p}
        t={easeOutCubic(segment(t, 0, 0.4))}
      />
      <Rings cx={70} cy={54} rings={rings} p={p} t={segment(t, 0.35, 1)} />
      <circle cx={70} cy={54} r={(small ? 8 : 7) * node} fill={p.accent} />
    </g>
  );
};

export const R07Art: React.FC<ArtProps> = (props) => (
  <PSignal {...props} small={false} />
);
export const R07Small: React.FC<ArtProps> = (props) => (
  <PSignal {...props} small />
);

/* ------------------------------------------------------------------ */
/* R08 p Planet                                                        */
/* ------------------------------------------------------------------ */

const PPlanet: React.FC<ArtProps & { small: boolean }> = ({ t, p, small }) => {
  const orbit = easeInOutCubic(segment(t, 0.55, 1));
  const from = -110;
  const to = from + 120 * orbit;
  const sat = polar(69, 54, 44, 44, to);
  return (
    <g>
      <Stem
        x={30}
        y0={22}
        y1={118}
        w={small ? 14 : 12}
        p={p}
        t={easeOutCubic(segment(t, 0, 0.35))}
      />
      <Planet
        cx={69}
        cy={54}
        R={32}
        step={small ? 11 : 6.4}
        maxR={small ? 5.4 : 3.1}
        ghostR={small ? 1.8 : 0.8}
        L={sweepLight(easeInOutCubic(segment(t, 0.2, 0.9)))}
        appear={segment(t, 0.1, 0.5)}
        p={p}
      />
      {orbit > 0 ? (
        <g>
          <path
            d={arcPath(69, 54, 44, 44, from, to)}
            fill="none"
            stroke={p.secondary}
            strokeWidth={small ? 5 : 3}
            strokeLinecap="round"
          />
          <circle
            cx={f2(sat.x)}
            cy={f2(sat.y)}
            r={small ? 7 : 5}
            fill={p.accent}
          />
        </g>
      ) : null}
    </g>
  );
};

export const R08Art: React.FC<ArtProps> = (props) => (
  <PPlanet {...props} small={false} />
);
export const R08Small: React.FC<ArtProps> = (props) => (
  <PPlanet {...props} small />
);
