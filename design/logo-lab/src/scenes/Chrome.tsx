import React from "react";
import { AbsoluteFill } from "remotion";
import { colors, fonts } from "../tokens";

/** Background with a faint fine-dot texture (a quiet halftone nod). */
export const Backdrop: React.FC<{
  bg?: string;
  dot?: string;
  children?: React.ReactNode;
}> = ({ bg = colors.background, dot = colors.hairline, children }) => {
  // Unique id: several backdrops (with different dot colors) can share one frame.
  const patternId = `fine-dots-${React.useId().replace(/:/g, "")}`;
  return (
    <AbsoluteFill style={{ backgroundColor: bg }}>
      <svg
        width="100%"
        height="100%"
        style={{ position: "absolute", inset: 0 }}
      >
        <defs>
          <pattern
            id={patternId}
            width={24}
            height={24}
            patternUnits="userSpaceOnUse"
          >
            <circle cx={12} cy={12} r={1.1} fill={dot} />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill={`url(#${patternId})`} />
      </svg>
      {children}
    </AbsoluteFill>
  );
};

export const MonoLabel: React.FC<{
  children: React.ReactNode;
  color?: string;
  size?: number;
  style?: React.CSSProperties;
}> = ({ children, color = colors.muted, size = 20, style }) => (
  <div
    style={{
      fontFamily: fonts.mono,
      fontSize: size,
      letterSpacing: "0.04em",
      color,
      ...style,
    }}
  >
    {children}
  </div>
);
