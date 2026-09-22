import React from "react";
import { AbsoluteFill } from "remotion";
import { CONCEPTS } from "../concepts";
import { colors, darkPalette, lightPalette, type Palette } from "../tokens";
import { Backdrop, MonoLabel } from "./Chrome";

const CELL_LOCKUP_W = 360;

/** 4x2 grid of all lockups for side-by-side comparison. */
export const ContactSheet: React.FC = () => (
  <Backdrop>
    <AbsoluteFill style={{ padding: "48px 64px", flexDirection: "column" }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          marginBottom: 32,
        }}
      >
        <MonoLabel color={colors.text}>
          puls3 / logo lab / contact sheet
        </MonoLabel>
        <MonoLabel>8 concepts · lockups</MonoLabel>
      </div>
      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gridTemplateRows: "repeat(2, 1fr)",
          gap: 24,
        }}
      >
        {CONCEPTS.map((c) => (
          <div
            key={c.code}
            style={{
              backgroundColor: colors.surface,
              border: `1px solid ${colors.hairline}`,
              borderRadius: 20,
              padding: 28,
              display: "flex",
              flexDirection: "column",
            }}
          >
            <MonoLabel size={18} color={colors.text}>
              {c.code} · {c.name}
            </MonoLabel>
            <div
              style={{
                flex: 1,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <c.Lockup
                height={(CELL_LOCKUP_W * c.lockupSize.h) / c.lockupSize.w}
              />
            </div>
            <MonoLabel size={15} style={{ lineHeight: 1.45 }}>
              {c.mark}
            </MonoLabel>
          </div>
        ))}
      </div>
    </AbsoluteFill>
  </Backdrop>
);

const MarkRow: React.FC<{
  palette: Palette;
  title: string;
  labelColor: string;
  dot: string;
}> = ({ palette, title, labelColor, dot }) => (
  <div style={{ flex: 1, position: "relative" }}>
    <Backdrop bg={palette.bg} dot={dot}>
      <AbsoluteFill style={{ padding: "40px 64px", flexDirection: "column" }}>
        <MonoLabel color={labelColor}>{title}</MonoLabel>
        <div
          style={{
            flex: 1,
            display: "grid",
            gridTemplateColumns: "repeat(8, 1fr)",
            alignItems: "center",
          }}
        >
          {CONCEPTS.map((c) => (
            <div
              key={c.code}
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 22,
              }}
            >
              <div style={{ display: "flex", alignItems: "flex-end", gap: 20 }}>
                <c.Mark size={64} palette={palette} />
                <c.Mark size={32} palette={palette} />
              </div>
              <MonoLabel
                size={15}
                color={labelColor}
                style={{ textAlign: "center" }}
              >
                {c.code}
                <br />
                {c.name}
              </MonoLabel>
            </div>
          ))}
        </div>
      </AbsoluteFill>
    </Backdrop>
  </div>
);

/** Marks only at 64 px and 32 px, on dark and light, to check small-size legibility. */
export const ContactSheetMarks: React.FC = () => (
  <AbsoluteFill style={{ flexDirection: "column" }}>
    <MarkRow
      palette={darkPalette}
      title={`marks · 64 px + 32 px · on ${colors.background}`}
      labelColor={colors.muted}
      dot={colors.hairline}
    />
    <MarkRow
      palette={lightPalette}
      title={`marks · 64 px + 32 px · on ${colors.paper}`}
      labelColor={colors.ink}
      dot={colors.hairlineLight}
    />
  </AbsoluteFill>
);
