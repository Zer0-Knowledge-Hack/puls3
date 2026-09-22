import React from "react";
import { AbsoluteFill } from "remotion";
import { colors, darkPalette, lightPalette, type Palette } from "../tokens";
import { HalftonePulse } from "../concepts/c01-halftone-pulse";
import { Backdrop, MonoLabel } from "../scenes/Chrome";
import { C01Small, FaviconTile } from "./c01small";
import {
  lockupGeometry,
  LockupSvg,
  wordmarkExtent,
  WordmarkSvg,
} from "./lockup";
import {
  layoutOf,
  option,
  optionsOf,
  type Direction,
  type Option3,
} from "./options";

/* ------------------------------------------------------------------ */
/* Finalists (chosen after reviewing R3-DirA..D)                        */
/* ------------------------------------------------------------------ */

export const FINALISTS: { id: string; rationale: string }[] = [
  {
    id: "D1",
    rationale:
      "Light, wide, weightless Unbounded; the p holds a mini C01, so the name carries the heartbeat.",
  },
  {
    id: "A3b",
    rationale:
      "Bold and legible at every size; only the 3 pulses, extending the mark's halftone into the name.",
  },
  {
    id: "D3",
    rationale:
      "Round-dot matrix all the way: a telemetry readout that speaks C01's halftone natively.",
  },
  {
    id: "D4",
    rationale:
      "Michroma's extended telemetry calm plus the heartbeat in the p: the most space-program option.",
  },
];

/* ------------------------------------------------------------------ */
/* Shared pieces                                                       */
/* ------------------------------------------------------------------ */

const Header: React.FC<{ title: string; right: string }> = ({
  title,
  right,
}) => (
  <div
    style={{
      display: "flex",
      justifyContent: "space-between",
      marginBottom: 22,
    }}
  >
    <MonoLabel color={colors.text}>{title}</MonoLabel>
    <MonoLabel>{right}</MonoLabel>
  </div>
);

/** Mark-box height (px) that fits the whole lockup inside maxW x maxH. */
const fitMark = (opt: Option3, maxW: number, maxH: number) => {
  const g = lockupGeometry(opt);
  return Math.min((maxW * 128) / (g.w + 6), (maxH * 128) / g.h);
};

/** Font size (px) that makes the standalone wordmark exactly `h` px tall. */
const wordmarkFontSizeForHeight = (opt: Option3, h: number) => {
  const { top, bottom } = wordmarkExtent(opt);
  return (h * 1000) / (bottom - top);
};

const optionLabel = (o: Option3) => `${o.id} · ${o.font} ${o.weight}`;

/* ------------------------------------------------------------------ */
/* R3-C01Small                                                         */
/* ------------------------------------------------------------------ */

const Labeled: React.FC<{
  label: string;
  color: string;
  children: React.ReactNode;
}> = ({ label, color, children }) => (
  <div
    style={{
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 14,
    }}
  >
    <div style={{ height: 128, display: "flex", alignItems: "center" }}>
      {children}
    </div>
    <MonoLabel
      size={14}
      color={color}
      style={{ textAlign: "center", whiteSpace: "pre" }}
    >
      {label}
    </MonoLabel>
  </div>
);

const BrowserTab: React.FC<{ mode: "dark" | "light" }> = ({ mode }) => {
  const dark = mode === "dark";
  const bar = dark ? colors.chromeDark : colors.chromeLight;
  const tab = dark ? colors.surface : colors.white;
  const text = dark ? colors.text : colors.ink;
  return (
    <div
      style={{
        width: 420,
        borderRadius: 12,
        overflow: "hidden",
        border: `1px solid ${dark ? colors.hairline : colors.hairlineLight}`,
      }}
    >
      <div
        style={{
          background: bar,
          padding: "10px 10px 0",
          display: "flex",
          gap: 6,
        }}
      >
        <div
          style={{
            background: tab,
            borderRadius: "10px 10px 0 0",
            padding: "9px 14px",
            display: "flex",
            alignItems: "center",
            gap: 10,
            width: 250,
          }}
        >
          <FaviconTile size={16} mode={mode} />
          <span
            style={{
              fontFamily: "Arial, sans-serif",
              fontSize: 13,
              color: text,
            }}
          >
            puls3 · agent hub on Stellar
          </span>
          <span
            style={{
              marginLeft: "auto",
              fontFamily: "Arial",
              fontSize: 13,
              color: colors.muted,
            }}
          >
            ×
          </span>
        </div>
      </div>
      <div style={{ background: tab, padding: "10px 14px" }}>
        <div
          style={{
            background: bar,
            borderRadius: 16,
            padding: "7px 14px",
            fontFamily: "Arial, sans-serif",
            fontSize: 13,
            color: colors.muted,
          }}
        >
          app.puls3.xyz
        </div>
      </div>
    </div>
  );
};

const C01SmallRow: React.FC<{ mode: "dark" | "light" }> = ({ mode }) => {
  const p: Palette = mode === "dark" ? darkPalette : lightPalette;
  const label = mode === "dark" ? colors.muted : colors.ink;
  return (
    <div style={{ flex: 1, position: "relative" }}>
      <Backdrop
        bg={p.bg}
        dot={mode === "dark" ? colors.hairline : colors.hairlineLight}
      >
        <AbsoluteFill style={{ padding: "30px 64px", flexDirection: "column" }}>
          <MonoLabel color={label}>on {p.bg} · C01 full vs C01-small</MonoLabel>
          <div
            style={{ flex: 1, display: "flex", alignItems: "center", gap: 44 }}
          >
            <Labeled label={"C01 full\n128 px"} color={label}>
              <HalftonePulse.Mark size={128} palette={p} />
            </Labeled>
            <Labeled label={"C01 full\n64 px"} color={label}>
              <HalftonePulse.Mark size={64} palette={p} />
            </Labeled>
            <Labeled label={"C01 full\n16 px (before)"} color={label}>
              <HalftonePulse.Mark size={16} palette={p} />
            </Labeled>
            <div
              style={{
                width: 1,
                height: 150,
                background:
                  mode === "dark" ? colors.hairline : colors.hairlineLight,
              }}
            />
            <Labeled label={"small\n32 px"} color={label}>
              <C01Small size={32} palette={p} />
            </Labeled>
            <Labeled label={"small\n24 px"} color={label}>
              <C01Small size={24} palette={p} />
            </Labeled>
            <Labeled label={"small\n16 px"} color={label}>
              <C01Small size={16} palette={p} />
            </Labeled>
            <Labeled label={"small 16 px\nzoom x6"} color={label}>
              <C01Small size={96} palette={p} level={16} />
            </Labeled>
            <Labeled label={"favicon\n32 / 16"} color={label}>
              <div style={{ display: "flex", alignItems: "flex-end", gap: 10 }}>
                <FaviconTile size={32} mode={mode} />
                <FaviconTile size={16} mode={mode} />
              </div>
            </Labeled>
            <div style={{ marginLeft: "auto" }}>
              <BrowserTab mode={mode} />
            </div>
          </div>
        </AbsoluteFill>
      </Backdrop>
    </div>
  );
};

export const R3C01Small: React.FC = () => (
  <AbsoluteFill style={{ flexDirection: "column" }}>
    <C01SmallRow mode="dark" />
    <C01SmallRow mode="light" />
  </AbsoluteFill>
);

/* ------------------------------------------------------------------ */
/* R3-DirA..D                                                          */
/* ------------------------------------------------------------------ */

const DIR_TITLE: Record<Direction, string> = {
  A: "A · halftone / dot-matrix",
  B: "B · space age (1960s-70s mission lettering)",
  C: "C · thin and extended (telemetry)",
  D: "D · custom cuts (outlined paths)",
};

const OptionCell: React.FC<{ o: Option3; w: number; h: number }> = ({
  o,
  w,
  h,
}) => {
  const mark = fitMark(o, w - 48, h * 0.5);
  return (
    <div
      style={{
        backgroundColor: colors.surface,
        border: `1px solid ${colors.hairline}`,
        borderRadius: 18,
        padding: "18px 22px",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <MonoLabel size={16} color={colors.text}>
        {optionLabel(o)}
      </MonoLabel>
      <MonoLabel size={13} style={{ marginTop: 4 }}>
        {o.treatment}
      </MonoLabel>
      <div
        style={{
          flex: 1,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <LockupSvg opt={o} height={mark} mode="live" />
      </div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 16,
          borderTop: `1px solid ${colors.hairline}`,
          paddingTop: 12,
        }}
      >
        <MonoLabel size={12}>24 px</MonoLabel>
        <div style={{ height: 24, display: "flex", alignItems: "center" }}>
          <WordmarkSvg
            opt={o}
            fontSize={wordmarkFontSizeForHeight(o, 24)}
            mode="live"
          />
        </div>
      </div>
      <MonoLabel size={12} style={{ marginTop: 10, lineHeight: 1.4 }}>
        {o.note}
      </MonoLabel>
    </div>
  );
};

const DirSheet: React.FC<{ dir: Direction }> = ({ dir }) => {
  const opts = optionsOf(dir);
  const cols = opts.length > 6 ? 4 : opts.length > 4 ? 3 : 2;
  const rows = Math.ceil(opts.length / cols);
  const innerW = 1920 - 128;
  const innerH = 1080 - 88 - 50;
  const cellW = (innerW - (cols - 1) * 20) / cols;
  const cellH = (innerH - (rows - 1) * 20) / rows;
  return (
    <Backdrop>
      <AbsoluteFill
        style={{ padding: "40px 64px 48px", flexDirection: "column" }}
      >
        <Header
          title={`puls3 / logo lab / round 3 / ${DIR_TITLE[dir]}`}
          right="C01 + wordmark · 24 px preview"
        />
        <div
          style={{
            flex: 1,
            display: "grid",
            gridTemplateColumns: `repeat(${cols}, 1fr)`,
            gridTemplateRows: `repeat(${rows}, 1fr)`,
            gap: 20,
          }}
        >
          {opts.map((o) => (
            <OptionCell key={o.id} o={o} w={cellW} h={cellH} />
          ))}
        </div>
      </AbsoluteFill>
    </Backdrop>
  );
};

export const R3DirA: React.FC = () => <DirSheet dir="A" />;
export const R3DirB: React.FC = () => <DirSheet dir="B" />;
export const R3DirC: React.FC = () => <DirSheet dir="C" />;
export const R3DirD: React.FC = () => <DirSheet dir="D" />;

/* ------------------------------------------------------------------ */
/* R3-Finalists                                                        */
/* ------------------------------------------------------------------ */

const AppBar: React.FC<{ o: Option3 }> = ({ o }) => (
  <div
    style={{
      height: 56,
      width: 470,
      background: colors.surface,
      borderRadius: 12,
      border: `1px solid ${colors.hairline}`,
      display: "flex",
      alignItems: "center",
      padding: "0 16px",
      gap: 10,
    }}
  >
    <C01Small size={28} />
    <WordmarkSvg opt={o} fontSize={wordmarkFontSizeForHeight(o, 22)} />
    <div style={{ marginLeft: "auto", display: "flex", gap: 16 }}>
      <MonoLabel size={12}>Studio</MonoLabel>
      <MonoLabel size={12}>Marketplace</MonoLabel>
    </div>
  </div>
);

const Tile: React.FC<{ bg: string; children: React.ReactNode }> = ({
  bg,
  children,
}) => (
  <div
    style={{
      background: bg,
      borderRadius: 14,
      border: `1px solid ${colors.hairline}`,
      height: "100%",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      overflow: "hidden",
    }}
  >
    {children}
  </div>
);

export const R3Finalists: React.FC = () => (
  <Backdrop>
    <AbsoluteFill style={{ padding: "36px 64px", flexDirection: "column" }}>
      <Header
        title="puls3 / logo lab / round 3 / finalists"
        right="lockup dark · lockup light · wordmark · app bar"
      />
      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "250px 1fr 1fr 0.8fr 500px",
          gridTemplateRows: `repeat(${FINALISTS.length}, 1fr)`,
          gap: 14,
        }}
      >
        {FINALISTS.map(({ id, rationale }, i) => {
          const o = option(id);
          const m = fitMark(o, 330, 120);
          return (
            <React.Fragment key={id}>
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "center",
                  gap: 6,
                }}
              >
                <MonoLabel size={16} color={colors.accent}>
                  #{i + 1} {id}
                </MonoLabel>
                <MonoLabel size={14} color={colors.text}>
                  {o.font} {o.weight}
                </MonoLabel>
                <MonoLabel size={11} style={{ lineHeight: 1.4 }}>
                  {rationale}
                </MonoLabel>
              </div>
              <Tile bg={colors.background}>
                <LockupSvg opt={o} height={m} />
              </Tile>
              <Tile bg={colors.paper}>
                <LockupSvg opt={o} height={m} p={lightPalette} />
              </Tile>
              <Tile bg={colors.background}>
                <WordmarkSvg
                  opt={o}
                  fontSize={Math.min(
                    90,
                    (260 * 1000) / (layoutOf(o).width + 80),
                  )}
                />
              </Tile>
              <Tile bg={colors.background}>
                <AppBar o={o} />
              </Tile>
            </React.Fragment>
          );
        })}
      </div>
    </AbsoluteFill>
  </Backdrop>
);
