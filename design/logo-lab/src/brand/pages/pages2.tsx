import React from "react";
import { brandDark, brandLight, colors, GRID } from "../../tokens";
import { HalftonePulse } from "../../concepts/c01-halftone-pulse";
import { WordmarkGlyphs } from "../../round3/lockup";
import { contrast, ratio } from "../contrast";
import {
  BrandLogo,
  BrandMark,
  BrandWordmark,
  LOGO_HALFTONE,
  lockupGeo,
} from "../logo";
import {
  Body,
  Content,
  H2,
  Label,
  Mono,
  Page,
  Panel,
  Placeholder,
  Verdict,
  bf,
  doto,
} from "../ui";

/* 07 · Clear space and minimum sizes -------------------------------------- */

/** Center dot of C01: radius 4.6 units on the 128 grid. Clear space = 4 of its diameters. */
export const CORE_DOT_D = 9.2;
export const CLEAR_SPACE_UNITS = CORE_DOT_D * 4;

const ClearSpaceDiagram: React.FC<{ height: number }> = ({ height }) => {
  const g = lockupGeo;
  const contentW = g.w - 16;
  const c = CLEAR_SPACE_UNITS;
  const pad = 16;
  const vb = {
    x: -c - pad,
    y: -c - pad,
    w: contentW + 2 * (c + pad),
    h: 128 + 2 * (c + pad),
  };
  const dash = {
    fill: "none",
    stroke: colors.accent,
    strokeWidth: 0.8,
    strokeDasharray: "3 2",
  };
  return (
    <svg
      width={(vb.w * height) / vb.h}
      height={height}
      viewBox={`${vb.x} ${vb.y} ${vb.w} ${vb.h}`}
    >
      <rect
        x={-c}
        y={-c}
        width={contentW + 2 * c}
        height={128 + 2 * c}
        {...dash}
      />
      <rect
        x={0}
        y={0}
        width={contentW}
        height={128}
        fill="none"
        stroke={colors.lavender}
        strokeWidth={0.5}
      />
      <HalftonePulse.Mark size={GRID} />
      <g transform={`translate(${g.x0} ${g.baseline}) scale(${g.s})`}>
        <WordmarkGlyphs opt={LOGO_HALFTONE} p={brandDark} />
      </g>
      {/* four core dots measure the clear space on the left and on top */}
      {[0, 1, 2, 3].map((i) => (
        <React.Fragment key={i}>
          <circle
            cx={-c + CORE_DOT_D * (i + 0.5)}
            cy={64}
            r={CORE_DOT_D / 2}
            fill={colors.accent}
          />
          <circle
            cx={contentW / 2}
            cy={-c + CORE_DOT_D * (i + 0.5)}
            r={CORE_DOT_D / 2}
            fill={colors.accent}
          />
          <circle
            cx={contentW + c - CORE_DOT_D * (i + 0.5)}
            cy={64}
            r={CORE_DOT_D / 2}
            fill={colors.accent}
          />
          <circle
            cx={contentW / 2}
            cy={128 + c - CORE_DOT_D * (i + 0.5)}
            r={CORE_DOT_D / 2}
            fill={colors.accent}
          />
        </React.Fragment>
      ))}
    </svg>
  );
};

const MinSize: React.FC<{
  label: string;
  spec: string;
  children: React.ReactNode;
}> = ({ label, spec, children }) => (
  <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
    <div style={{ height: 60, display: "flex", alignItems: "flex-end" }}>
      {children}
    </div>
    <H2 size={17} color={colors.text}>
      {label}
    </H2>
    <Mono size={13}>{spec}</Mono>
  </div>
);

export const P07ClearSpace: React.FC = () => (
  <Page n={7} section="Clear space">
    <Content
      kicker="07 · Clear space and minimum sizes"
      title="Give the pulse room"
      intro="Unit c = the diameter of C01's center dot (0.072 × mark height). Keep 4c clear on every side of the lockup, the mark or the wordmark. Nothing enters this area: text, edges, other logos."
    >
      <div style={{ display: "flex", gap: 24, height: "100%" }}>
        <Panel
          style={{
            flex: 1.55,
            alignItems: "center",
            justifyContent: "center",
            gap: 18,
          }}
        >
          <ClearSpaceDiagram height={430} />
          <Mono color={colors.accent}>
            clear space = 4c ≈ 0.29 × mark height
          </Mono>
        </Panel>
        <Panel
          style={{ flex: 1, padding: 32, gap: 28, justifyContent: "center" }}
        >
          <Label>Minimum sizes (digital)</Label>
          <div style={{ display: "flex", gap: 40, alignItems: "flex-end" }}>
            <MinSize label="Lockup" spec="mark ≥ 24 px">
              <BrandLogo height={24} />
            </MinSize>
            <MinSize label="Mark" spec="≥ 16 px">
              <BrandMark size={16} />
            </MinSize>
            <MinSize label="Wordmark" spec="height ≥ 14 px">
              <BrandWordmark height={14} />
            </MinSize>
          </div>
          <Label>Minimum sizes (print)</Label>
          <Body size={16}>
            Lockup 25 mm wide · mark 6 mm · wordmark 18 mm wide. Below these,
            use the mark only.
          </Body>
          <Label>At small sizes</Label>
          <Body size={16}>
            Below the thresholds on page 06 the logo switches automatically to
            C01-small and the solid 3. Never scale the halftone versions down by
            hand.
          </Body>
        </Panel>
      </div>
    </Content>
  </Page>
);

/* 08 · Misuse ------------------------------------------------------------ */

/** Data for the misuse page only: the Stellar brand yellow, which puls3 must never use. */
const FORBIDDEN_STELLAR_YELLOW = "#FDDA24";

const Busy: React.FC = () => (
  <svg
    width="100%"
    height="100%"
    viewBox="0 0 400 220"
    preserveAspectRatio="xMidYMid slice"
    style={{ position: "absolute", inset: 0 }}
  >
    <rect width={400} height={220} fill={colors.chromeLight} />
    {Array.from({ length: 36 }).map((_, i) => {
      const x = (i * 97) % 400;
      const y = (i * 53) % 220;
      const fills = [
        colors.success,
        colors.lavender,
        colors.accent,
        colors.surface,
        colors.white,
        colors.lavenderOnLight,
      ];
      return (
        <circle
          key={i}
          cx={x}
          cy={y}
          r={18 + ((i * 7) % 40)}
          fill={fills[i % fills.length]}
          opacity={0.75}
        />
      );
    })}
  </svg>
);

const MISUSE: { reason: string; node: React.ReactNode; bg?: string }[] = [
  {
    reason: "Don't stretch or squash the logo.",
    node: (
      <div style={{ transform: "scale(1.45, 0.75)" }}>
        <BrandLogo height={80} />
      </div>
    ),
  },
  {
    reason: "Don't rotate the logo.",
    node: (
      <div style={{ transform: "rotate(-14deg)" }}>
        <BrandLogo height={80} />
      </div>
    ),
  },
  {
    reason: "Never recolor with Stellar yellow (#FDDA24).",
    node: (
      <BrandLogo
        height={80}
        palette={{
          ...brandDark,
          accent: FORBIDDEN_STELLAR_YELLOW,
          secondary: FORBIDDEN_STELLAR_YELLOW,
        }}
      />
    ),
  },
  {
    reason: `Don't use dark-theme amber on white (${ratio(colors.accent, colors.white)}): use on-light colors.`,
    bg: colors.white,
    node: (
      <BrandLogo
        height={80}
        palette={{ ...brandDark, bg: colors.white, ink: colors.ink }}
      />
    ),
  },
  {
    reason: "Don't force the halftone 3 at small sizes: it breaks up.",
    node: <BrandLogo height={34} three="halftone" mark="full" />,
  },
  {
    reason: "Don't place the logo on busy photos or patterns.",
    node: (
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Busy />
        <div style={{ position: "relative" }}>
          <BrandLogo height={80} />
        </div>
      </div>
    ),
  },
  {
    reason: "Don't add drop shadows, glows or bevels.",
    node: (
      <div
        style={{
          filter: `drop-shadow(6px 8px 4px ${colors.shadow}) drop-shadow(0 0 14px ${colors.accent})`,
        }}
      >
        <BrandLogo height={80} />
      </div>
    ),
  },
  {
    reason: "Doto is an accent face: never set the logo in it.",
    node: (
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        <BrandMark size={80} />
        <span style={{ ...doto(900), fontSize: 64, color: colors.text }}>
          puls<span style={{ color: colors.accent }}>3</span>
        </span>
      </div>
    ),
  },
  {
    reason:
      "Never merge the mark with, or shape it like, the Stellar monogram.",
    node: (
      <div style={{ position: "relative", width: 190, height: 110 }}>
        <div style={{ position: "absolute", left: 60, top: 0 }}>
          <Placeholder w={110} h={110} label="Stellar logo" />
        </div>
        <div style={{ position: "absolute", left: 20, top: 15 }}>
          <BrandMark size={80} />
        </div>
      </div>
    ),
  },
];

export const P08Misuse: React.FC = () => (
  <Page n={8} section="Misuse">
    <Content kicker="08 · Misuse" title="Don't">
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(3, 1fr)",
          gridTemplateRows: "repeat(3, 1fr)",
          gap: 16,
          height: "100%",
        }}
      >
        {MISUSE.map((m, i) => (
          <Panel key={i} bg={colors.surface}>
            <div
              style={{
                flex: 1,
                position: "relative",
                background: m.bg ?? colors.background,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                overflow: "hidden",
              }}
            >
              {m.node}
            </div>
            <div
              style={{
                display: "flex",
                alignItems: "center",
                gap: 12,
                padding: "12px 16px",
              }}
            >
              <Verdict ok={false} size={26} />
              <Body size={15} color={colors.text}>
                {m.reason}
              </Body>
            </div>
          </Panel>
        ))}
      </div>
    </Content>
  </Page>
);

/* 09 / 10 · Color ---------------------------------------------------------- */

type Swatch = {
  token: string;
  hex: string;
  role: string;
  kind: "text" | "graphic" | "surface";
};

const grade = (r: number, kind: Swatch["kind"]) =>
  kind === "surface"
    ? "surface"
    : kind === "text"
      ? r >= 4.5
        ? "AA text"
        : "fails text"
      : r >= 3
        ? "≥ 3:1 graphic"
        : "fails 3:1";

const SwatchCard: React.FC<{
  s: Swatch;
  on: { name: string; hex: string }[];
  light?: boolean;
}> = ({ s, on, light }) => (
  <Panel
    bg={light ? colors.white : colors.surface}
    border={light ? colors.hairlineLight : colors.hairline}
  >
    <div
      style={{
        flex: 1,
        minHeight: 90,
        background: s.hex,
        borderBottom: `1px solid ${light ? colors.hairlineLight : colors.hairline}`,
      }}
    />
    <div
      style={{
        padding: "14px 18px",
        display: "flex",
        flexDirection: "column",
        gap: 6,
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <Mono size={14} color={light ? colors.ink : colors.text}>
          {s.token}
        </Mono>
        <Mono size={14} color={light ? colors.mutedOnLight : colors.muted}>
          {s.hex}
        </Mono>
      </div>
      <Body size={14} color={light ? colors.mutedOnLight : colors.muted}>
        {s.role}
      </Body>
      {on.map((b) => {
        const r = contrast(s.hex, b.hex);
        const g = grade(r, s.kind);
        const bad = g.startsWith("fails");
        return (
          <Mono
            key={b.name}
            size={12}
            color={bad ? colors.danger : light ? colors.ink : colors.text}
          >
            on {b.name}: {r.toFixed(2)}:1 · {g}
          </Mono>
        );
      })}
    </div>
  </Panel>
);

const DARK_SWATCHES: Swatch[] = [
  {
    token: "background",
    hex: colors.background,
    role: "Page background",
    kind: "surface",
  },
  {
    token: "surface",
    hex: colors.surface,
    role: "Cards, bars, panels",
    kind: "surface",
  },
  {
    token: "text",
    hex: colors.text,
    role: "Primary text, wordmark",
    kind: "text",
  },
  { token: "muted", hex: colors.muted, role: "Secondary text", kind: "text" },
  {
    token: "accent",
    hex: colors.accent,
    role: "Pulse core, the 3, key actions",
    kind: "text",
  },
  {
    token: "lavender",
    hex: colors.lavender,
    role: "Pulse edge, secondary accents",
    kind: "text",
  },
  {
    token: "success",
    hex: colors.success,
    role: "Positive states",
    kind: "text",
  },
  {
    token: "hairline",
    hex: colors.hairline,
    role: "Dividers and borders (decorative)",
    kind: "surface",
  },
];

export const P09ColorDark: React.FC = () => (
  <Page n={9} section="Color · dark">
    <Content
      kicker="09 · Color · dark palette (default)"
      title="Deep space, warm signal"
      intro="Dark is the default. Amber is the signal: use it sparingly (the 3, the pulse core, primary actions). Lavender is the atmosphere. Ratios are WCAG 2.x."
    >
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, 1fr)",
          gridTemplateRows: "repeat(2, 1fr)",
          gap: 18,
          height: "100%",
        }}
      >
        {DARK_SWATCHES.map((s) => (
          <SwatchCard
            key={s.token}
            s={s}
            on={
              s.kind === "surface"
                ? [{ name: "text", hex: colors.text }]
                : [
                    { name: "background", hex: colors.background },
                    { name: "surface", hex: colors.surface },
                  ]
            }
          />
        ))}
      </div>
    </Content>
  </Page>
);

const LIGHT_SWATCHES: Swatch[] = [
  {
    token: "paper",
    hex: colors.paper,
    role: "Light background",
    kind: "surface",
  },
  {
    token: "ink",
    hex: colors.ink,
    role: "Primary text, wordmark",
    kind: "text",
  },
  {
    token: "mutedOnLight",
    hex: colors.mutedOnLight,
    role: "Secondary text on light",
    kind: "text",
  },
  {
    token: "accentOnLight",
    hex: colors.accentOnLight,
    role: "Solid 3, pulse core, actions",
    kind: "text",
  },
  {
    token: "lavenderOnLight",
    hex: colors.lavenderOnLight,
    role: "Pulse edge, secondary accents",
    kind: "text",
  },
];

export const P10ColorLight: React.FC = () => (
  <Page n={10} section="Color · light" light>
    <Content
      light
      kicker="10 · Color · light palette"
      title="On-light variants"
      intro={`The dark-theme amber and lavender fail on paper (${ratio(colors.accent, colors.paper)} and ${ratio(colors.lavender, colors.paper)}). On light backgrounds always switch to the on-light variants: solid text ≥ 4.5:1, graphics ≥ 3:1.`}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 18,
          height: "100%",
        }}
      >
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(5, 1fr)",
            gap: 16,
            flex: 1.05,
          }}
        >
          {LIGHT_SWATCHES.map((s) => (
            <SwatchCard
              key={s.token}
              s={s}
              light
              on={
                s.kind === "surface"
                  ? [{ name: "ink", hex: colors.ink }]
                  : [
                      { name: "paper", hex: colors.paper },
                      { name: "white", hex: colors.white },
                    ]
              }
            />
          ))}
        </div>
        <div style={{ display: "flex", gap: 18, flex: 1 }}>
          <Panel
            bg={colors.background}
            style={{
              flex: 1,
              alignItems: "center",
              justifyContent: "center",
              gap: 14,
            }}
          >
            <BrandLogo height={120} />
            <Mono size={13}>
              dark · accent {ratio(colors.accent, colors.background)} · lavender{" "}
              {ratio(colors.lavender, colors.background)}
            </Mono>
          </Panel>
          <Panel
            bg={colors.paper}
            border={colors.hairlineLight}
            style={{
              flex: 1,
              alignItems: "center",
              justifyContent: "center",
              gap: 14,
            }}
          >
            <BrandLogo height={120} palette={brandLight} />
            <Mono size={13} color={colors.mutedOnLight}>
              light · accentOnLight {ratio(colors.accentOnLight, colors.paper)}{" "}
              · lavenderOnLight {ratio(colors.lavenderOnLight, colors.paper)}
            </Mono>
          </Panel>
          <Panel
            bg={colors.paper}
            border={colors.hairlineLight}
            style={{
              flex: 0.8,
              alignItems: "center",
              justifyContent: "center",
              gap: 14,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
              <Verdict ok={false} size={26} />
              <BrandLogo
                height={70}
                palette={{ ...brandDark, bg: colors.paper, ink: colors.ink }}
              />
            </div>
            <Mono size={13} color={colors.mutedOnLight}>
              dark-theme amber on paper: {ratio(colors.accent, colors.paper)}
            </Mono>
          </Panel>
        </div>
      </div>
    </Content>
  </Page>
);

/* 11 · Typography --------------------------------------------------------- */

const Specimen: React.FC<{
  name: string;
  role: string;
  children: React.ReactNode;
}> = ({ name, role, children }) => (
  <div
    style={{
      borderTop: `1px solid ${colors.hairline}`,
      padding: "12px 0",
      display: "flex",
      gap: 24,
      alignItems: "center",
    }}
  >
    <div style={{ width: 230, flexShrink: 0 }}>
      <H2 size={17} color={colors.text}>
        {name}
      </H2>
      <Mono size={12}>{role}</Mono>
    </div>
    <div style={{ flex: 1, overflow: "hidden", whiteSpace: "nowrap" }}>
      {children}
    </div>
  </div>
);

const DotoUse: React.FC<{
  ok: boolean;
  label: string;
  children: React.ReactNode;
}> = ({ ok, label, children }) => (
  <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 8 }}>
    <div
      style={{
        flex: 1,
        background: colors.background,
        borderRadius: 12,
        border: `1px solid ${colors.hairline}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 10,
        overflow: "hidden",
      }}
    >
      {children}
    </div>
    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
      <Verdict ok={ok} size={20} />
      <Mono size={12} color={colors.text}>
        {label}
      </Mono>
    </div>
  </div>
);

export const P11Typography: React.FC = () => (
  <Page n={11} section="Typography">
    <Content kicker="11 · Typography" title="Four voices, clear jobs">
      <div style={{ display: "flex", gap: 28, height: "100%" }}>
        <div style={{ flex: 1.45, display: "flex", flexDirection: "column" }}>
          <Specimen name="Unbounded" role="display, headlines · 500/700">
            <span
              style={{
                fontFamily: bf.display,
                fontWeight: 700,
                fontSize: 50,
                color: colors.text,
              }}
            >
              Agents on Stellar
            </span>
          </Specimen>
          <Specimen name="Doto · ROND 100" role="accents only · 900">
            <span style={{ ...doto(900), fontSize: 50, color: colors.accent }}>
              1,284 AGENTS LIVE
            </span>
          </Specimen>
          <Specimen name="Manrope" role="UI and body · 400-800">
            <span
              style={{ fontFamily: bf.ui, fontSize: 24, color: colors.text }}
            >
              Create an agent, give it a wallet, hire it in USDC.
            </span>
          </Specimen>
          <Specimen name="JetBrains Mono" role="addresses, tx hashes, code">
            <span
              style={{ fontFamily: bf.data, fontSize: 21, color: colors.text }}
            >
              GBZX…4KQ7 · tx 9f3a…c21e · 12.50 USDC
            </span>
          </Specimen>
          <div
            style={{
              borderTop: `1px solid ${colors.hairline}`,
              paddingTop: 14,
              display: "flex",
              gap: 14,
              flex: 1,
            }}
          >
            <DotoUse ok label="big numbers, stats">
              <span style={{ ...doto(900), fontSize: 46, color: colors.text }}>
                42.7K
              </span>
            </DotoUse>
            <DotoUse ok label="loading / status">
              <span
                style={{ ...doto(900), fontSize: 26, color: colors.accent }}
              >
                SYNCING 64%
              </span>
            </DotoUse>
            <DotoUse ok label="event graphics">
              <span
                style={{ ...doto(900), fontSize: 26, color: colors.lavender }}
              >
                HACK NIGHT
              </span>
            </DotoUse>
            <DotoUse ok={false} label="as the logo">
              <span style={{ ...doto(900), fontSize: 34, color: colors.text }}>
                puls3
              </span>
            </DotoUse>
            <DotoUse ok={false} label="body text">
              <span
                style={{
                  ...doto(900),
                  fontSize: 11,
                  color: colors.text,
                  whiteSpace: "normal",
                  lineHeight: 1.3,
                }}
              >
                Agents can be hired and paid in USDC on the Stellar network
                today.
              </span>
            </DotoUse>
            <DotoUse ok={false} label="small UI labels">
              <span style={{ ...doto(900), fontSize: 12, color: colors.text }}>
                Settings · Wallet
              </span>
            </DotoUse>
          </div>
        </div>
        <Panel style={{ flex: 0.75, padding: 30, gap: 14 }}>
          <Label>Hierarchy</Label>
          <div
            style={{
              fontFamily: bf.display,
              fontWeight: 700,
              fontSize: 44,
              lineHeight: 1.05,
              color: colors.text,
            }}
          >
            Hire an agent
          </div>
          <Mono size={11}>H1 · Unbounded 700 · 56 / 44</Mono>
          <div
            style={{
              fontFamily: bf.display,
              fontWeight: 500,
              fontSize: 28,
              color: colors.text,
            }}
          >
            Top agents this week
          </div>
          <Mono size={11}>H2 · Unbounded 500 · 36 / 28</Mono>
          <div
            style={{
              fontFamily: bf.ui,
              fontSize: 17,
              lineHeight: 1.55,
              color: colors.text,
            }}
          >
            Each agent has its own Stellar wallet and on-chain identity. Pay per
            task in USDC, settled in seconds.
          </div>
          <Mono size={11}>Body · Manrope 400 · 16</Mono>
          <div
            style={{
              fontFamily: bf.ui,
              fontWeight: 500,
              fontSize: 13,
              color: colors.muted,
            }}
          >
            Updated 2 minutes ago
          </div>
          <Mono size={11}>Caption · Manrope 500 · 13 · muted</Mono>
          <div
            style={{
              fontFamily: bf.data,
              fontSize: 13,
              color: colors.lavender,
            }}
          >
            GBZX…4KQ7 → 12.50 USDC
          </div>
          <Mono size={11}>Data · JetBrains Mono 400 · 13</Mono>
          <div
            style={{
              ...doto(900),
              fontSize: 40,
              color: colors.accent,
              marginTop: 6,
            }}
          >
            98.2%
          </div>
          <Mono size={11}>Accent stat · Doto 900 ROND 100</Mono>
        </Panel>
      </div>
    </Content>
  </Page>
);
