/** Halftone helpers for round-2 marks. Pure math, no hooks. */

export type Dot = {
  x: number;
  y: number;
  u: number; // normalized x offset from center, -1..1
  v: number; // normalized y offset from center, -1..1
  d: number; // normalized distance from center, 0..1
};

/** Hexagonal dot grid clipped to a disc of radius R. */
export const hexDisc = (
  cx: number,
  cy: number,
  R: number,
  step: number,
): Dot[] => {
  const out: Dot[] = [];
  const rowH = step * 0.866;
  const n = Math.ceil(R / rowH) + 1;
  for (let j = -n; j <= n; j++) {
    const y = cy + j * rowH;
    const shift = j % 2 === 0 ? 0 : step / 2;
    for (let i = -n - 1; i <= n + 1; i++) {
      const x = cx + i * step + shift;
      const d = Math.hypot(x - cx, y - cy) / R;
      if (d <= 1) out.push({ x, y, u: (x - cx) / R, v: (y - cy) / R, d });
    }
  }
  return out;
};

/** The 7-dot hex "flower" (center + 6), used as a small-size halftone core. */
export const hexFlower = (cx: number, cy: number, dist: number) => [
  { x: cx, y: cy, center: true },
  ...Array.from({ length: 6 }, (_, i) => {
    const a = (i * Math.PI) / 3 + Math.PI / 6;
    return {
      x: cx + Math.cos(a) * dist,
      y: cy + Math.sin(a) * dist,
      center: false,
    };
  }),
];

export type Vec3 = { x: number; y: number; z: number };

const norm = (v: Vec3): Vec3 => {
  const l = Math.hypot(v.x, v.y, v.z) || 1;
  return { x: v.x / l, y: v.y / l, z: v.z / l };
};

/**
 * Light direction that swings around the sphere as `sweep` goes 0 -> 1:
 * from behind (fully dark) to the final key light at the upper left (or right, if mirrored).
 */
export const sweepLight = (sweep: number, mirror = false): Vec3 => {
  const a = Math.PI * (1 - sweep) + ((50 * Math.PI) / 180) * sweep; // 180deg -> 50deg
  const sx = mirror ? 1 : -1;
  return norm({ x: sx * Math.sin(a) * 0.9, y: -0.4, z: Math.cos(a) });
};

/** Lambert shading on a unit sphere at normalized (u, v). */
export const lambert = (u: number, v: number, L: Vec3) => {
  const w2 = 1 - u * u - v * v;
  if (w2 < 0) return 0;
  return Math.max(0, u * L.x + v * L.y + Math.sqrt(w2) * L.z);
};

/**
 * Concentric-ring dot layout clipped to a disc: gives a perfectly round silhouette
 * (a hex grid clipped to a circle reads as a hexagon once the rim dots get large).
 */
export const ringDisc = (
  cx: number,
  cy: number,
  R: number,
  step: number,
): Dot[] => {
  const out: Dot[] = [{ x: cx, y: cy, u: 0, v: 0, d: 0 }];
  for (let k = 1; k * step <= R; k++) {
    const r = k * step;
    const n = Math.max(6, Math.round((2 * Math.PI * r) / step));
    const offset = k % 2 === 0 ? 0 : Math.PI / n;
    for (let i = 0; i < n; i++) {
      const a = (i * 2 * Math.PI) / n + offset;
      const x = cx + Math.cos(a) * r;
      const y = cy + Math.sin(a) * r;
      out.push({ x, y, u: (x - cx) / R, v: (y - cy) / R, d: r / R });
    }
  }
  return out;
};
