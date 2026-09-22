import React from "react";
import { AbsoluteFill } from "remotion";
import { brandDark, brandLight, colors, type Palette } from "../tokens";
import { DOTO_FAMILY } from "./fonts";
import { BrandLogo } from "./logo";

/* ------------------------------ Type system ----------------------------- */

export const bf = {
  display: "'Unbounded', 'Helvetica Neue', Arial, sans-serif",
  ui: "Manrope, 'Helvetica Neue', Arial, sans-serif",
  data: "'JetBrains Mono', Consolas, monospace",
  doto: `'${DOTO_FAMILY}', monospace`,
} as const;

/** Doto with round dots (self-hosted variable font, ROND axis at 100). */
export const doto = (weight = 900): React.CSSProperties => ({
  fontFamily: bf.doto,
  fontWeight: weight,
  fontVariationSettings: `'ROND' 100, 'wght' ${weight}`,
});

export { radius, spacing, typeScale } from "./scale";

/* -------------------------------- Pages -------------------------------- */

export const PAGE_COUNT = 16;

export const Page: React.FC<{
  n: number;
  section: string;
  light?: boolean;
  children: React.ReactNode;
  bare?: boolean; // no header (cover)
}> = ({ n, section, light = false, children, bare = false }) => {
  const p = light ? brandLight : brandDark;
  const line = light ? colors.hairlineLight : colors.hairline;
  return (
    <AbsoluteFill
      style={{ backgroundColor: p.bg, fontFamily: bf.ui, color: p.ink }}
    >
      {!bare ? (
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            right: 0,
            height: 84,
            padding: "0 64px",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            borderBottom: `1px solid ${line}`,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
            <BrandLogo height={30} palette={p} />
            <Mono color={p.muted}>Brand Guidelines 2026</Mono>
          </div>
          <Mono color={p.muted}>
            {String(n).padStart(2, "0")} · {section}
          </Mono>
        </div>
      ) : null}
      <div
        style={{
          position: "absolute",
          top: bare ? 0 : 84,
          bottom: 64,
          left: 0,
          right: 0,
        }}
      >
        {children}
      </div>
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 64,
          padding: "0 64px",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          borderTop: `1px solid ${line}`,
        }}
      >
        <Mono color={p.muted}>puls3 · Brand Guidelines 2026</Mono>
        <Mono color={p.muted}>
          {String(n).padStart(2, "0")} / {PAGE_COUNT}
        </Mono>
      </div>
    </AbsoluteFill>
  );
};

/* ------------------------------ Primitives ------------------------------ */

export const Mono: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
  style?: React.CSSProperties;
}> = ({ children, color = colors.muted, size = 15, style }) => (
  <span
    style={{
      fontFamily: bf.data,
      fontSize: size,
      letterSpacing: "0.02em",
      color,
      ...style,
    }}
  >
    {children}
  </span>
);

export const H1: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
}> = ({ children, color, size = 52 }) => (
  <div
    style={{
      fontFamily: bf.display,
      fontWeight: 700,
      fontSize: size,
      lineHeight: 1.08,
      letterSpacing: "-0.01em",
      color,
    }}
  >
    {children}
  </div>
);

export const H2: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
}> = ({ children, color, size = 26 }) => (
  <div
    style={{
      fontFamily: bf.display,
      fontWeight: 500,
      fontSize: size,
      lineHeight: 1.2,
      color,
    }}
  >
    {children}
  </div>
);

export const Body: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
  style?: React.CSSProperties;
}> = ({ children, color = colors.muted, size = 19, style }) => (
  <div
    style={{
      fontFamily: bf.ui,
      fontWeight: 400,
      fontSize: size,
      lineHeight: 1.5,
      color,
      ...style,
    }}
  >
    {children}
  </div>
);

export const Label: React.FC<{ children: React.ReactNode; color?: string }> = ({
  children,
  color = colors.muted,
}) => (
  <div
    style={{
      fontFamily: bf.data,
      fontSize: 13,
      letterSpacing: "0.06em",
      textTransform: "uppercase",
      color,
    }}
  >
    {children}
  </div>
);

/** Content area with the standard margins and a title block. */
export const Content: React.FC<{
  title: string;
  kicker?: string;
  intro?: string;
  light?: boolean;
  children?: React.ReactNode;
}> = ({ title, kicker, intro, light = false, children }) => {
  const p = light ? brandLight : brandDark;
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        padding: "40px 64px 36px",
        display: "flex",
        flexDirection: "column",
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "flex-end",
          justifyContent: "space-between",
          gap: 48,
        }}
      >
        <div>
          {kicker ? <Label color={p.accent}>{kicker}</Label> : null}
          <div style={{ marginTop: 10 }}>
            <H1 color={p.ink} size={44}>
              {title}
            </H1>
          </div>
        </div>
        {intro ? (
          <Body
            color={p.muted}
            size={17}
            style={{ maxWidth: 720, textAlign: "right" }}
          >
            {intro}
          </Body>
        ) : null}
      </div>
      <div style={{ flex: 1, marginTop: 30, position: "relative" }}>
        {children}
      </div>
    </div>
  );
};

export const Panel: React.FC<{
  children: React.ReactNode;
  bg?: string;
  border?: string;
  style?: React.CSSProperties;
}> = ({ children, bg = colors.surface, border = colors.hairline, style }) => (
  <div
    style={{
      background: bg,
      border: `1px solid ${border}`,
      borderRadius: 18,
      position: "relative",
      overflow: "hidden",
      display: "flex",
      flexDirection: "column",
      ...style,
    }}
  >
    {children}
  </div>
);

/** Red cross / green tick badge for do-and-don't examples. */
export const Verdict: React.FC<{ ok: boolean; size?: number }> = ({
  ok,
  size = 30,
}) => (
  <svg width={size} height={size} viewBox="0 0 32 32">
    <circle cx={16} cy={16} r={15} fill={ok ? colors.success : colors.danger} />
    {ok ? (
      <path
        d="M9 16.5 L14 21 L23 11"
        fill="none"
        stroke={colors.ink}
        strokeWidth={3.2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    ) : (
      <path
        d="M10.5 10.5 L21.5 21.5 M21.5 10.5 L10.5 21.5"
        stroke={colors.ink}
        strokeWidth={3.2}
        strokeLinecap="round"
      />
    )}
  </svg>
);

/* ------------------------------ Pulse motif ------------------------------ */

/**
 * PulseBackground: a large halftone field whose dots shrink away from a center point.
 * `density` is the grid step in px; `maxR` the dot radius at the center.
 */
export const PulseBackground: React.FC<{
  width: number;
  height: number;
  cx: number;
  cy: number;
  radius: number;
  step?: number;
  maxR?: number;
  p?: Palette;
  opacity?: number;
}> = ({
  width,
  height,
  cx,
  cy,
  radius: R,
  step = 22,
  maxR = 7,
  p = brandDark,
  opacity = 1,
}) => {
  const dots: React.ReactNode[] = [];
  const rowH = step * 0.866;
  for (let j = 0; j * rowH < height + step; j++) {
    const y = j * rowH;
    const shift = j % 2 ? step / 2 : 0;
    for (let i = -1; i * step < width + step; i++) {
      const x = i * step + shift;
      const d = Math.hypot(x - cx, y - cy) / R;
      if (d > 1) continue;
      const r = maxR * Math.pow(1 - d, 1.4);
      if (r < 0.5) continue;
      dots.push(
        <circle
          key={`${i}-${j}`}
          cx={x.toFixed(1)}
          cy={y.toFixed(1)}
          r={r.toFixed(2)}
          fill={d < 0.35 ? p.accent : p.secondary}
        />,
      );
    }
  }
  return (
    <svg
      width={width}
      height={height}
      style={{ position: "absolute", left: 0, top: 0, opacity }}
    >
      {dots}
    </svg>
  );
};

/** A dashed placeholder box that stands in for an official third-party asset. */
export const Placeholder: React.FC<{
  w: number;
  h: number;
  label: string;
  light?: boolean;
}> = ({ w, h, label, light = false }) => (
  <div
    style={{
      width: w,
      height: h,
      border: `2px dashed ${light ? colors.mutedOnLight : colors.muted}`,
      borderRadius: 10,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      textAlign: "center",
      padding: 10,
      boxSizing: "border-box",
    }}
  >
    <Mono size={13} color={light ? colors.mutedOnLight : colors.muted}>
      {label}
    </Mono>
  </div>
);
