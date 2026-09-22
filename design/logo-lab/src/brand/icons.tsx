import React from "react";
import type { Palette } from "../tokens";

/**
 * puls3 icon set (sample). Rules: 48-unit grid with a 4-unit safe margin, 2.5-unit round
 * strokes in ink, no fills except one halftone accent (amber / lavender dots) per icon.
 */
export const ICON_GRID = 48;
const SW = 2.5;

type IconProps = { p: Palette };

const S: React.FC<{ p: Palette; children: React.ReactNode }> = ({
  p,
  children,
}) => (
  <g
    fill="none"
    stroke={p.ink}
    strokeWidth={SW}
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    {children}
  </g>
);

const Agent: React.FC<IconProps> = ({ p }) => (
  <g>
    <S p={p}>
      <rect x={9} y={15} width={30} height={24} rx={8} />
      <path d="M24 15 V9" />
    </S>
    <circle cx={19} cy={27} r={2.6} fill={p.ink} />
    <circle cx={29} cy={27} r={2.6} fill={p.ink} />
    <circle cx={24} cy={6.5} r={3.2} fill={p.accent} />
  </g>
);

const Wallet: React.FC<IconProps> = ({ p }) => (
  <g>
    <S p={p}>
      <rect x={8} y={15} width={32} height={25} rx={5} />
      <path d="M13 15 L30 8.5 L33 15" />
      <path d="M40 23 H32 a4 4 0 0 0 0 8 H40" />
    </S>
    <circle cx={33} cy={27} r={2.2} fill={p.accent} />
  </g>
);

const Pulse: React.FC<IconProps> = ({ p }) => (
  <g>
    <circle cx={24} cy={24} r={5.5} fill={p.accent} />
    {Array.from({ length: 8 }).map((_, i) => {
      const a = (i * Math.PI) / 4;
      return (
        <circle
          key={i}
          cx={24 + Math.cos(a) * 12}
          cy={24 + Math.sin(a) * 12}
          r={2.4}
          fill={p.ink}
        />
      );
    })}
    {Array.from({ length: 12 }).map((_, i) => {
      const a = (i * Math.PI) / 6 + Math.PI / 12;
      return (
        <circle
          key={i}
          cx={24 + Math.cos(a) * 18.5}
          cy={24 + Math.sin(a) * 18.5}
          r={1.4}
          fill={p.secondary}
        />
      );
    })}
  </g>
);

const Studio: React.FC<IconProps> = ({ p }) => (
  <g>
    <S p={p}>
      <path d="M9 14 H39 M9 24 H39 M9 34 H39" />
    </S>
    {[
      [17, 14, false],
      [31, 24, true],
      [22, 34, false],
    ].map(([x, y, accent], i) => (
      <circle
        key={i}
        cx={x as number}
        cy={y as number}
        r={4.2}
        fill={accent ? p.accent : p.bg}
        stroke={accent ? p.accent : p.ink}
        strokeWidth={SW}
      />
    ))}
  </g>
);

const Marketplace: React.FC<IconProps> = ({ p }) => (
  <g>
    <S p={p}>
      <path d="M8 18 L12 9 H36 L40 18" />
      <path d="M8 18 a4 4 0 0 0 8 0 a4 4 0 0 0 8 0 a4 4 0 0 0 8 0 a4 4 0 0 0 8 0" />
      <path d="M11 23 V39 H37 V23" />
      <path d="M20 39 V30 H28 V39" />
    </S>
    <circle cx={24} cy={13.5} r={2} fill={p.accent} />
  </g>
);

const Payment: React.FC<IconProps> = ({ p }) => (
  <g>
    <S p={p}>
      <circle cx={19} cy={24} r={12} />
      <circle cx={19} cy={24} r={5.5} />
      <path d="M34 24 H43 M39 19.5 L43.5 24 L39 28.5" />
    </S>
    <circle cx={34} cy={17} r={1.3} fill={p.secondary} />
    <circle cx={37.5} cy={14} r={1.7} fill={p.secondary} />
    <circle cx={41.5} cy={11} r={2.1} fill={p.accent} />
  </g>
);

export const ICONS: { name: string; C: React.FC<IconProps> }[] = [
  { name: "agent", C: Agent },
  { name: "wallet", C: Wallet },
  { name: "pulse", C: Pulse },
  { name: "studio", C: Studio },
  { name: "marketplace", C: Marketplace },
  { name: "payment", C: Payment },
];

export const Icon: React.FC<{
  name: string;
  size: number;
  p: Palette;
  grid?: boolean;
}> = ({ name, size, p, grid = false }) => {
  const I = ICONS.find((i) => i.name === name)?.C ?? Agent;
  return (
    <svg
      width={size}
      height={size}
      viewBox={`0 0 ${ICON_GRID} ${ICON_GRID}`}
      role="img"
      aria-label={`${name} icon`}
    >
      {grid ? (
        <g stroke={p.secondary} strokeWidth={0.15} opacity={0.6}>
          {Array.from({ length: ICON_GRID + 1 }).map((_, i) => (
            <React.Fragment key={i}>
              <line x1={i} y1={0} x2={i} y2={ICON_GRID} />
              <line x1={0} y1={i} x2={ICON_GRID} y2={i} />
            </React.Fragment>
          ))}
          <rect
            x={4}
            y={4}
            width={40}
            height={40}
            fill="none"
            stroke={p.accent}
            strokeWidth={0.3}
            strokeDasharray="1 1"
          />
        </g>
      ) : null}
      <I p={p} />
    </svg>
  );
};
