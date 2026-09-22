import React from "react";
import {
  brandDark,
  brandLight,
  colors,
  GRID,
  monoInk,
  monoWhite,
  type Palette,
} from "../../tokens";
import { HalftonePulse } from "../../concepts/c01-halftone-pulse";
import { C01Small, FaviconTile } from "../../round3/c01small";
import { WordmarkGlyphs } from "../../round3/lockup";
import {
  BrandLogo,
  BrandMark,
  BrandWordmark,
  LOCKUP_HALFTONE_MIN_MARK_PX,
  LOGO_HALFTONE,
  LOGO_SOLID,
  MARK_FULL_MIN_PX,
  THREE_HALFTONE_MIN_PX,
  THREE_BBOX,
  THREE_UNITS,
  dotPitchForThree,
  lockupGeo,
  threePxForMark,
} from "../logo";
import {
  Body,
  Content,
  H1,
  H2,
  Label,
  Mono,
  Page,
  Panel,
  PulseBackground,
  bf,
  doto,
} from "../ui";

/* 01 · Cover ------------------------------------------------------------- */

export const P01Cover: React.FC = () => (
  <Page n={1} section="Cover" bare>
    <PulseBackground
      width={1920}
      height={1016}
      cx={1480}
      cy={500}
      radius={760}
      step={26}
      maxR={9}
      opacity={0.32}
    />
    <div
      style={{
        position: "absolute",
        left: 120,
        top: 250,
        display: "flex",
        flexDirection: "column",
        gap: 44,
      }}
    >
      <BrandLogo height={200} />
      <div>
        <H1 size={64} color={colors.text}>
          Brand Guidelines
        </H1>
        <div
          style={{
            ...doto(900),
            fontSize: 64,
            color: colors.accent,
            marginTop: 6,
            letterSpacing: "0.04em",
          }}
        >
          2026
        </div>
      </div>
      <Body size={22} style={{ maxWidth: 720 }}>
        The agent hub on Stellar. Identity, color, typography and usage rules
        for puls3.
      </Body>
      <Mono>v1.0 · September 2026 · draft for review</Mono>
    </div>
  </Page>
);

/* 02 · Brand essence ----------------------------------------------------- */

const EssenceCol: React.FC<{
  kicker: string;
  title: string;
  children: React.ReactNode;
}> = ({ kicker, title, children }) => (
  <Panel style={{ padding: 32, gap: 16, flex: 1 }}>
    <Label color={colors.accent}>{kicker}</Label>
    <H2 color={colors.text}>{title}</H2>
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      {children}
    </div>
  </Panel>
);

export const P02Essence: React.FC = () => (
  <Page n={2} section="Brand essence">
    <Content
      kicker="02 · Brand essence"
      title="A living signal for autonomous agents"
      intro="puls3 is the agent hub on Stellar. The name is a pulse: the heartbeat of agents that create, earn and pay on-chain. The 3 marks the non-EVM (Stellar) generation of pulse."
    >
      <div style={{ display: "flex", gap: 24, height: "100%" }}>
        <EssenceCol kicker="What it is" title="Agent Studio + Marketplace">
          <Body size={22}>
            <b style={{ color: colors.text }}>Agent Studio:</b> create AI
            agents, each with its own on-chain identity and Stellar wallet.
          </Body>
          <Body size={22}>
            <b style={{ color: colors.text }}>Marketplace:</b> find, hire and
            pay agents in USDC.
          </Body>
          <div
            style={{
              ...doto(900),
              fontSize: 56,
              color: colors.accent,
              marginTop: 18,
            }}
          >
            AGENTS · USDC
          </div>
        </EssenceCol>
        <EssenceCol kicker="The idea" title="The pulse">
          <div
            style={{
              display: "flex",
              justifyContent: "center",
              padding: "8px 0 14px",
            }}
          >
            <BrandMark size={250} />
          </div>
          <Body size={22}>
            A heartbeat frozen as a halftone field: an amber core that radiates
            outward into lavender. It is the moment an agent comes alive and
            starts to broadcast.
          </Body>
        </EssenceCol>
        <EssenceCol
          kicker="Relationship"
          title="Stellar's universe, not Stellar's clothes"
        >
          <Body size={22}>
            <b style={{ color: colors.text }}>Inspired:</b> depth, atmospheric
            movement, fine halftone textures, generous dark space.
          </Body>
          <Body size={22}>
            <b style={{ color: colors.text }}>Not copied:</b> our own amber and
            lavender, our own mark and type. Never Stellar yellow, never the
            Stellar monogram. The Stellar logo appears only in the official
            "Built on Stellar" lockup.
          </Body>
        </EssenceCol>
      </div>
    </Content>
  </Page>
);

/* 03 · Primary logo ------------------------------------------------------ */

export const P03Primary: React.FC = () => (
  <Page n={3} section="Primary logo">
    <Content kicker="03 · Primary logo" title="The puls3 logo">
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 70,
        }}
      >
        <BrandLogo height={330} />
        <Body size={20} style={{ textAlign: "center", maxWidth: 1100 }}>
          The C01 Halftone Pulse mark with the wordmark "puls3" set in Unbounded
          700. Only the "3" is built from halftone dots: the pulse carries from
          the mark into the name. The horizontal lockup is the primary form.
        </Body>
      </div>
    </Content>
  </Page>
);

/* 04 · Anatomy ----------------------------------------------------------- */

const AnnotatedLockup: React.FC<{ height: number }> = ({ height }) => {
  const g = lockupGeo;
  const x3 = LOGO_THREE.bbox[0] * g.s + g.x0;
  const w3 = (LOGO_THREE.bbox[2] - LOGO_THREE.bbox[0]) * g.s;
  const y3 = g.baseline + LOGO_THREE.bbox[1] * g.s;
  const h3 = THREE_UNITS * g.s;
  const xh = g.baseline - 52;
  const vbX = -30;
  const vbY = g.y0 - 30;
  const vbW = g.w + 130;
  const vbH = g.h + 70;
  const line = {
    stroke: colors.accent,
    strokeWidth: 0.6,
    strokeDasharray: "2 2",
  };
  const guide = { stroke: colors.lavender, strokeWidth: 0.5 };
  const text = { fontFamily: bf.data, fontSize: 7, fill: colors.muted };
  return (
    <svg
      width={(vbW * height) / vbH}
      height={height}
      viewBox={`${vbX} ${vbY} ${vbW} ${vbH}`}
    >
      <HalftonePulse.Mark size={GRID} />
      <g transform={`translate(${g.x0} ${g.baseline}) scale(${g.s})`}>
        <WordmarkGlyphs opt={LOGO_HALFTONE} p={brandDark} />
      </g>
      <rect x={0} y={0} width={128} height={128} fill="none" {...line} />
      <line
        x1={-20}
        x2={g.w + 20}
        y1={64}
        y2={64}
        {...guide}
        strokeDasharray="1 2"
      />
      <line
        x1={g.x0 - 6}
        x2={g.w + 20}
        y1={g.baseline}
        y2={g.baseline}
        {...guide}
      />
      <line x1={g.x0 - 6} x2={g.w + 20} y1={xh} y2={xh} {...guide} />
      <rect x={x3} y={y3} width={w3} height={h3} fill="none" {...line} />
      <line
        x1={128}
        x2={g.x0}
        y1={140}
        y2={140}
        stroke={colors.accent}
        strokeWidth={0.8}
      />
      <text
        x={(128 + g.x0) / 2}
        y={148}
        textAnchor="middle"
        {...text}
        fill={colors.accent}
      >
        gap 0.31 M
      </text>
      <text x={0} y={140} {...text}>
        M = mark height
      </text>
      <text x={g.w + 22} y={g.baseline + 1.5} {...text}>
        baseline
      </text>
      <text x={g.w + 22} y={xh + 1.5} {...text}>
        x-height 0.41 M
      </text>
      <text x={g.w + 22} y={65.5} {...text}>
        mark center
      </text>
      <text x={x3} y={y3 - 3} {...text} fill={colors.accent}>
        halftone 3
      </text>
    </svg>
  );
};

const LOGO_THREE = { bbox: THREE_BBOX };

const Part: React.FC<{ title: string; children: React.ReactNode }> = ({
  title,
  children,
}) => (
  <div style={{ borderTop: `1px solid ${colors.hairline}`, paddingTop: 16 }}>
    <H2 size={21} color={colors.text}>
      {title}
    </H2>
    <Body size={16} style={{ marginTop: 8 }}>
      {children}
    </Body>
  </div>
);

export const P04Anatomy: React.FC = () => (
  <Page n={4} section="Logo anatomy">
    <Content
      kicker="04 · Anatomy and construction"
      title="Three parts, one pulse"
    >
      <div style={{ display: "flex", gap: 48, height: "100%" }}>
        <Panel
          style={{ flex: 1.6, alignItems: "center", justifyContent: "center" }}
        >
          <AnnotatedLockup height={330} />
        </Panel>
        <div
          style={{
            flex: 1,
            display: "flex",
            flexDirection: "column",
            gap: 22,
            justifyContent: "center",
          }}
        >
          <Part title="1 · The mark (C01 Halftone Pulse)">
            A hexagonal dot field clipped to a circle. Dots swell toward the
            center; the inner 62% of the radius is amber, the edge is lavender.
          </Part>
          <Part title="2 · The wordmark">
            "puls3" in Unbounded 700, lowercase, no added tracking. The x-height
            is 0.41 M and is centered on the mark's horizontal axis. Gap between
            mark and wordmark: 0.31 M.
          </Part>
          <Part title="3 · The halftone 3">
            The "3" is resampled on a dot grid of 5.6% of the em. Dots grow
            toward the glyph's center: amber core, lavender edge, the same logic
            as the mark.
          </Part>
        </div>
      </div>
    </Content>
  </Page>
);

/* 05 · Versions ---------------------------------------------------------- */

const VARIANTS: { name: string; p: Palette; bg: string }[] = [
  { name: "On dark", p: brandDark, bg: colors.background },
  { name: "On light", p: brandLight, bg: colors.paper },
  { name: "Mono white", p: monoWhite, bg: colors.background },
  { name: "Mono ink", p: monoInk, bg: colors.paper },
];

export const P05Versions: React.FC = () => (
  <Page n={5} section="Logo versions">
    <Content kicker="05 · Versions" title="Lockup, mark, wordmark">
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "170px repeat(4, 1fr)",
          gridTemplateRows: "30px repeat(3, 1fr)",
          gap: 14,
          height: "100%",
        }}
      >
        <div />
        {VARIANTS.map((v) => (
          <Label key={v.name}>{v.name}</Label>
        ))}
        {(["Horizontal lockup", "Mark only", "Wordmark only"] as const).map(
          (row) => (
            <React.Fragment key={row}>
              <div style={{ display: "flex", alignItems: "center" }}>
                <H2 size={18} color={colors.text}>
                  {row}
                </H2>
              </div>
              {VARIANTS.map((v) => (
                <div
                  key={v.name}
                  style={{
                    background: v.bg,
                    borderRadius: 14,
                    border: `1px solid ${colors.hairline}`,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  {row === "Horizontal lockup" ? (
                    <BrandLogo height={96} palette={v.p} />
                  ) : row === "Mark only" ? (
                    <BrandMark size={150} palette={v.p} />
                  ) : (
                    <BrandWordmark height={78} palette={v.p} />
                  )}
                </div>
              ))}
            </React.Fragment>
          ),
        )}
      </div>
    </Content>
  </Page>
);

/** Just the "3" of the logo, rendered at h px tall. */
const Three: React.FC<{ h: number; halftone: boolean }> = ({ h, halftone }) => {
  const [x0, y0, x1, y1] = THREE_BBOX;
  const pad = 20;
  const vw = x1 - x0 + pad * 2;
  const vh = y1 - y0 + pad * 2;
  return (
    <svg
      width={(vw * h) / (y1 - y0)}
      height={(vh * h) / (y1 - y0)}
      viewBox={`${x0 - pad} ${y0 - pad} ${vw} ${vh}`}
    >
      <WordmarkGlyphs
        opt={halftone ? LOGO_HALFTONE : LOGO_SOLID}
        p={brandDark}
      />
    </svg>
  );
};

/* 06 · Size rules -------------------------------------------------------- */

const LADDER = [120, 90, LOCKUP_HALFTONE_MIN_MARK_PX, 52, 34, 24];

export const P06SizeRules: React.FC = () => (
  <Page n={6} section="Size rules">
    <Content
      kicker="06 · Size rules"
      title="Halftone when it can breathe"
      intro={`The halftone 3 is used only when the rendered "3" is at least ${THREE_HALFTONE_MIN_PX} px tall (dot pitch ≈ ${dotPitchForThree(THREE_HALFTONE_MIN_PX).toFixed(1)} px). In the lockup that is a mark of ${LOCKUP_HALFTONE_MIN_MARK_PX} px or more. Below it the 3 is solid amber.`}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 20,
          height: "100%",
        }}
      >
        <Panel
          style={{
            flex: 0.8,
            padding: "22px 28px",
            flexDirection: "row",
            alignItems: "flex-end",
            gap: 34,
          }}
        >
          {LADDER.map((h) => {
            const t = threePxForMark(h);
            const halftone = t >= THREE_HALFTONE_MIN_PX;
            return (
              <div
                key={h}
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: 12,
                  alignItems: "flex-start",
                }}
              >
                <BrandLogo height={h} />
                <Mono size={13} color={halftone ? colors.accent : colors.muted}>
                  mark {h}px
                  <br />3 = {t.toFixed(0)}px · {halftone ? "halftone" : "solid"}
                </Mono>
              </div>
            );
          })}
        </Panel>
        <div style={{ flex: 1, display: "flex", gap: 20 }}>
          <Panel style={{ flex: 1.1, padding: "20px 26px", gap: 14 }}>
            <Label>Why: the 3 alone at real size</Label>
            <div
              style={{
                display: "flex",
                gap: 34,
                alignItems: "flex-end",
                flex: 1,
              }}
            >
              {([24, 40, 64] as const).map((h) => (
                <div
                  key={h}
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: 10,
                    alignItems: "center",
                  }}
                >
                  <div
                    style={{ display: "flex", gap: 10, alignItems: "flex-end" }}
                  >
                    <Three h={h} halftone />
                    <Three h={h} halftone={false} />
                  </div>
                  <Mono
                    size={12}
                    color={
                      h >= THREE_HALFTONE_MIN_PX
                        ? colors.success
                        : colors.danger
                    }
                  >
                    3 = {h}px{" "}
                    {h >= THREE_HALFTONE_MIN_PX ? "halftone ok" : "use solid"}
                  </Mono>
                </div>
              ))}
            </div>
          </Panel>
          <Panel style={{ flex: 1.3, padding: "20px 26px", gap: 14 }}>
            <Label>
              Mark: C01 full ≥ {MARK_FULL_MIN_PX} px, then C01-small
            </Label>
            <div
              style={{
                display: "flex",
                gap: 26,
                alignItems: "flex-end",
                flex: 1,
              }}
            >
              {[96, 64, 48].map((s) => (
                <div
                  key={s}
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <BrandMark size={s} />
                  <Mono size={12}>full {s}</Mono>
                </div>
              ))}
              <div
                style={{
                  width: 1,
                  alignSelf: "stretch",
                  background: colors.hairline,
                }}
              />
              {[32, 24, 16].map((s) => (
                <div
                  key={s}
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    gap: 8,
                  }}
                >
                  <C01Small size={s} />
                  <Mono size={12}>small {s}</Mono>
                </div>
              ))}
            </div>
          </Panel>
          <Panel style={{ flex: 1, padding: "20px 26px", gap: 14 }}>
            <Label>Favicon · 16 px in a browser tab</Label>
            <div style={{ flex: 1, display: "flex", alignItems: "center" }}>
              <div
                style={{
                  width: "100%",
                  borderRadius: 10,
                  overflow: "hidden",
                  border: `1px solid ${colors.hairline}`,
                }}
              >
                <div
                  style={{
                    background: colors.chromeDark,
                    padding: "8px 8px 0",
                  }}
                >
                  <div
                    style={{
                      background: colors.surface,
                      borderRadius: "8px 8px 0 0",
                      padding: "8px 12px",
                      display: "flex",
                      alignItems: "center",
                      gap: 8,
                      width: 230,
                    }}
                  >
                    <FaviconTile size={16} mode="dark" />
                    <span
                      style={{
                        fontFamily: bf.ui,
                        fontSize: 13,
                        color: colors.text,
                      }}
                    >
                      puls3 · agent hub
                    </span>
                  </div>
                </div>
                <div
                  style={{ background: colors.surface, padding: "8px 12px" }}
                >
                  <div
                    style={{
                      background: colors.chromeDark,
                      borderRadius: 14,
                      padding: "5px 12px",
                    }}
                  >
                    <Mono size={12}>app.puls3.xyz</Mono>
                  </div>
                </div>
              </div>
            </div>
          </Panel>
        </div>
      </div>
    </Content>
  </Page>
);
