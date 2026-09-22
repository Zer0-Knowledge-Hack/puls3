/** Pure math helpers shared by the marks. No Remotion hooks here. */

export const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

/** Maps t from [a, b] into [0, 1], clamped. */
export const segment = (t: number, a: number, b: number) =>
  clamp01((t - a) / (b - a));

export const easeOutCubic = (t: number) => 1 - Math.pow(1 - clamp01(t), 3);

export const easeInOutCubic = (t: number) => {
  const x = clamp01(t);
  return x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
};

/** Point on a circle/ellipse; angle in degrees, 0 = right, clockwise (SVG y-down). */
export const polar = (
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  deg: number,
) => {
  const a = (deg * Math.PI) / 180;
  return { x: cx + rx * Math.cos(a), y: cy + ry * Math.sin(a) };
};

/** Elliptical arc path from `from` to `to` degrees, drawn clockwise. */
export const arcPath = (
  cx: number,
  cy: number,
  rx: number,
  ry: number,
  from: number,
  to: number,
) => {
  const s = polar(cx, cy, rx, ry, from);
  const e = polar(cx, cy, rx, ry, to);
  const sweep = (((to - from) % 360) + 360) % 360;
  const large = sweep > 180 ? 1 : 0;
  return `M ${s.x.toFixed(2)} ${s.y.toFixed(2)} A ${rx} ${ry} 0 ${large} 1 ${e.x.toFixed(2)} ${e.y.toFixed(2)}`;
};

/**
 * Stroke props that "draw" a path from 0 to 1 using pathLength normalization.
 * At t = 1 no dash is applied, so static exports stay clean.
 */
export const drawOn = (t: number) =>
  t >= 1
    ? { pathLength: 1 }
    : {
        pathLength: 1,
        strokeDasharray: "1 1",
        strokeDashoffset: 1 - clamp01(t),
      };

/** Deterministic pseudo-random in [0, 1) for a given integer seed. */
export const hash01 = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};
