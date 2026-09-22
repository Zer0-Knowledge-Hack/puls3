import React from "react";
import { AbsoluteFill } from "remotion";
import { colors, GRID } from "../tokens";
import { FaviconTile } from "../round3/c01small";
import { BrandMark, MarkArt } from "./logo";
import { OgBanner } from "./pages/pages3";
import { brandDark } from "../tokens";

/** App / favicon icon: C01-small tile up to 32 px, C01 full on a rounded dark tile above. */
export const BrandIcon: React.FC<{ size: number }> = ({ size }) =>
  size <= 32 ? (
    <FaviconTile size={size} mode="dark" />
  ) : (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox={`0 0 ${GRID} ${GRID}`}
    >
      <rect width={GRID} height={GRID} rx={28} fill={colors.background} />
      <g transform="translate(64 64) scale(0.8) translate(-64 -64)">
        <MarkArt px={size * 0.8} p={brandDark} />
      </g>
    </svg>
  );

export const FaviconAsset: React.FC<{ size: number }> = ({ size }) => (
  <AbsoluteFill>
    <BrandIcon size={size} />
  </AbsoluteFill>
);

export const OgAsset: React.FC = () => (
  <AbsoluteFill>
    <OgBanner />
  </AbsoluteFill>
);

/** Square avatar; the mark sits inside the circle-safe area (68% of the side). */
export const AvatarAsset: React.FC = () => (
  <AbsoluteFill
    style={{
      background: colors.background,
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <BrandMark size={544} />
  </AbsoluteFill>
);
