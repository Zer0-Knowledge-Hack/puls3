import React from "react";
import { AbsoluteFill } from "remotion";
import { colors, darkPalette, lightPalette, type Palette } from "../tokens";
import { Backdrop, MonoLabel } from "../scenes/Chrome";
import { makeRLockup, rConcept, rLockupSize, R_CONCEPTS } from "./concepts";
import {
  TREATMENT_LABEL,
  TYPE_SPECS,
  typeSpec,
  wordmarkWidthEm,
  WordmarkSvg,
  type FontKey,
  type Treatment,
} from "./type";

const Header: React.FC<{ title: string; right: string }> = ({
  title,
  right,
}) => (
  <div
    style={{
      display: "flex",
      justifyContent: "space-between",
      marginBottom: 28,
    }}
  >
    <MonoLabel color={colors.text}>{title}</MonoLabel>
    <MonoLabel>{right}</MonoLabel>
  </div>
);

const Card: React.FC<{
  children: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ children, style }) => (
  <div
    style={{
      backgroundColor: colors.surface,
      border: `1px solid ${colors.hairline}`,
      borderRadius: 20,
      padding: 24,
      display: "flex",
      flexDirection: "column",
      ...style,
    }}
  >
    {children}
  </div>
);

/* ----------------------------- R-Marks ----------------------------- */

export const RMarks: React.FC = () => (
  <Backdrop>
    <AbsoluteFill style={{ padding: "48px 64px", flexDirection: "column" }}>
      <Header
        title="puls3 / logo lab / round 2 / marks"
        right="R01–R08 · from C01, C04, C07"
      />
      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gridTemplateRows: "repeat(2, 1fr)",
          gap: 24,
        }}
      >
        {R_CONCEPTS.map((c) => (
          <Card key={c.code}>
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
              <c.RMark size={230} variant="full" />
            </div>
            <MonoLabel size={14} style={{ lineHeight: 1.45 }}>
              {c.rationale}
            </MonoLabel>
          </Card>
        ))}
      </div>
    </AbsoluteFill>
  </Backdrop>
);

/* --------------------------- R-MarksSmall -------------------------- */

const SmallRow: React.FC<{
  palette: Palette;
  title: string;
  labelColor: string;
  dot: string;
}> = ({ palette, title, labelColor, dot }) => (
  <div style={{ flex: 1, position: "relative" }}>
    <Backdrop bg={palette.bg} dot={dot}>
      <AbsoluteFill style={{ padding: "36px 64px", flexDirection: "column" }}>
        <MonoLabel color={labelColor}>{title}</MonoLabel>
        <div
          style={{
            flex: 1,
            display: "grid",
            gridTemplateColumns: "repeat(8, 1fr)",
            alignItems: "center",
          }}
        >
          {R_CONCEPTS.map((c) => (
            <div
              key={c.code}
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 20,
              }}
            >
              <div style={{ display: "flex", alignItems: "flex-end", gap: 22 }}>
                <c.RMark size={64} palette={palette} variant="full" />
                <c.RMark size={32} palette={palette} variant="auto" />
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

export const RMarksSmall: React.FC = () => (
  <AbsoluteFill style={{ flexDirection: "column" }}>
    <SmallRow
      palette={darkPalette}
      title={`round 2 · 64 px (full) + 32 px (small variant) · on ${colors.background}`}
      labelColor={colors.muted}
      dot={colors.hairline}
    />
    <SmallRow
      palette={lightPalette}
      title={`round 2 · 64 px (full) + 32 px (small variant) · on ${colors.paper}`}
      labelColor={colors.ink}
      dot={colors.hairlineLight}
    />
  </AbsoluteFill>
);

/* ---------------------------- R-TypeSheet -------------------------- */

const TREATMENTS: Treatment[] = [1, 2, 3];

export const RTypeSheet: React.FC = () => (
  <Backdrop>
    <AbsoluteFill style={{ padding: "40px 64px", flexDirection: "column" }}>
      <Header
        title="puls3 / logo lab / round 2 / wordmark type study"
        right="T1 lowercase · T2 UPPERCASE tracked · T3 custom pulse"
      />
      <div
        style={{
          flex: 1,
          display: "grid",
          gridTemplateColumns: "250px repeat(3, 1fr)",
          gridTemplateRows: `repeat(${TYPE_SPECS.length}, 1fr)`,
          columnGap: 16,
          rowGap: 10,
        }}
      >
        {TYPE_SPECS.map((s) => (
          <React.Fragment key={s.key}>
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                justifyContent: "center",
              }}
            >
              <MonoLabel
                size={17}
                color={s.cliche ? colors.muted : colors.text}
              >
                {s.label}
              </MonoLabel>
              <MonoLabel size={12} style={{ marginTop: 4 }}>
                {s.weight} ·{" "}
                {s.custom === "counter"
                  ? "T3: amber p-counter"
                  : "T3: halftone pulse"}
              </MonoLabel>
            </div>
            {TREATMENTS.map((tr) => (
              <div
                key={tr}
                style={{
                  backgroundColor: colors.surface,
                  border: `1px solid ${colors.hairline}`,
                  borderRadius: 12,
                  position: "relative",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  overflow: "hidden",
                }}
              >
                <div style={{ position: "absolute", left: 10, top: 6 }}>
                  <MonoLabel size={11}>{TREATMENT_LABEL[tr]}</MonoLabel>
                </div>
                <FitWordmark font={s.key} treatment={tr} maxW={440} maxH={62} />
              </div>
            ))}
          </React.Fragment>
        ))}
      </div>
    </AbsoluteFill>
  </Backdrop>
);

/** Renders the wordmark as large as possible within maxW x maxH (viewBox is 1.12 em tall). */
const FitWordmark: React.FC<{
  font: FontKey;
  treatment: Treatment;
  maxW: number;
  maxH: number;
}> = ({ font, treatment, maxW, maxH }) => {
  const spec = typeSpec(font);
  const wEm = wordmarkWidthEm(spec, treatment) + 0.08;
  const h = Math.min(maxH, (maxW / wEm) * 1.12);
  return (
    <WordmarkSvg spec={spec} treatment={treatment} height={h} p={darkPalette} />
  );
};

/* ----------------------------- R-Lockups --------------------------- */

/** Picks from the study (see caption). */
export const PICK_MARKS = ["R04", "R03", "R07"] as const;
export const PICK_FONTS: FontKey[] = ["Unbounded", "Michroma", "Sora"];
export const PICK_BEST = { mark: "R04", font: "Unbounded" as FontKey };

export const RLockups: React.FC = () => (
  <Backdrop>
    <AbsoluteFill style={{ padding: "44px 64px", flexDirection: "column" }}>
      <Header
        title="puls3 / logo lab / round 2 / lockups · 3 marks × 3 fonts"
        right="T1 lowercase"
      />
      <div
        style={{
          display: "grid",
          gridTemplateColumns: `200px repeat(${PICK_FONTS.length}, 1fr)`,
          gap: 18,
          flex: 1,
          gridTemplateRows: `40px repeat(${PICK_MARKS.length}, 1fr)`,
        }}
      >
        <div />
        {PICK_FONTS.map((f) => (
          <MonoLabel
            key={f}
            size={17}
            color={colors.text}
            style={{ alignSelf: "end" }}
          >
            {typeSpec(f).label}
          </MonoLabel>
        ))}
        {PICK_MARKS.map((code) => {
          const c = rConcept(code);
          return (
            <React.Fragment key={code}>
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  justifyContent: "center",
                }}
              >
                <MonoLabel size={17} color={colors.text}>
                  {c.code}
                </MonoLabel>
                <MonoLabel size={14}>{c.name}</MonoLabel>
              </div>
              {PICK_FONTS.map((f) => {
                const best = code === PICK_BEST.mark && f === PICK_BEST.font;
                const L = makeRLockup(c.Art, c.name, f, 1);
                const { w, h } = rLockupSize(typeSpec(f), 1);
                const width = 470;
                return (
                  <Card
                    key={f}
                    style={{
                      alignItems: "center",
                      justifyContent: "center",
                      position: "relative",
                      borderColor: best ? colors.accent : colors.hairline,
                    }}
                  >
                    {best ? (
                      <div style={{ position: "absolute", top: 12, left: 16 }}>
                        <MonoLabel size={13} color={colors.accent}>
                          ★ strongest
                        </MonoLabel>
                      </div>
                    ) : null}
                    <L height={Math.min(120, (width * h) / w)} />
                  </Card>
                );
              })}
            </React.Fragment>
          );
        })}
      </div>
      <MonoLabel size={16} style={{ marginTop: 22 }} color={colors.text}>
        Pick: {PICK_BEST.mark} {rConcept(PICK_BEST.mark).name} ×{" "}
        {typeSpec(PICK_BEST.font).label}
        <span style={{ color: colors.muted }}>
          {"  "}— reads at 32 px, owns the pulse + signal story, and the
          geometric sans feels spacious without sci-fi cliché.
        </span>
      </MonoLabel>
    </AbsoluteFill>
  </Backdrop>
);
