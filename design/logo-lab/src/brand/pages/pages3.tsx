import React from "react";
import { brandDark, brandLight, colors, type Palette } from "../../tokens";
import { C01Small } from "../../round3/c01small";
import { ICONS, Icon } from "../icons";
import { BrandLogo, BrandMark, BrandWordmark } from "../logo";
import {
  Body,
  Content,
  H2,
  Label,
  Mono,
  Page,
  Panel,
  Placeholder,
  PulseBackground,
  Verdict,
  bf,
  doto,
} from "../ui";

/* 12 · Graphic motif ----------------------------------------------------- */

export const P12Motif: React.FC = () => (
  <Page n={12} section="Graphic motif">
    <Content
      kicker="12 · Graphic motif"
      title="PulseBackground"
      intro="The halftone pulse as a texture: a hex dot field whose dots shrink away from one focal point. Amber only in the inner 35% of the radius, lavender beyond. It sets atmosphere; it never competes with content."
    >
      <div style={{ display: "flex", gap: 20, height: "100%" }}>
        <Panel bg={colors.background} style={{ flex: 1.3 }}>
          <PulseBackground
            width={1000}
            height={760}
            cx={760}
            cy={180}
            radius={640}
            step={22}
            maxR={7}
            opacity={0.55}
          />
          <div
            style={{
              position: "absolute",
              left: 36,
              bottom: 36,
              display: "flex",
              flexDirection: "column",
              gap: 10,
            }}
          >
            <Label color={colors.accent}>On dark · 55% opacity</Label>
            <div
              style={{
                fontFamily: bf.display,
                fontWeight: 700,
                fontSize: 40,
                color: colors.text,
                lineHeight: 1.1,
              }}
            >
              Your agents,
              <br />
              always on.
            </div>
          </div>
        </Panel>
        <div
          style={{ flex: 1, display: "flex", flexDirection: "column", gap: 20 }}
        >
          <Panel
            bg={colors.paper}
            border={colors.hairlineLight}
            style={{ flex: 1 }}
          >
            <PulseBackground
              width={780}
              height={330}
              cx={660}
              cy={40}
              radius={460}
              step={20}
              maxR={6}
              p={brandLight}
              opacity={0.5}
            />
            <div style={{ position: "absolute", left: 28, bottom: 26 }}>
              <Label color={colors.accentOnLight}>
                On light · on-light colors · 50%
              </Label>
            </div>
          </Panel>
          <Panel style={{ flex: 1.1, padding: 26, gap: 12 }}>
            <Label>Rules</Label>
            <Body size={16} color={colors.text}>
              Scale · grid step 18-28 px on screen; center dot ≥ 6 px. Density ·
              one focal point per surface, placed off the text block, usually at
              a corner or edge.
            </Body>
            <Body size={16} color={colors.text}>
              Color · amber core ≤ 35% of the radius, lavender beyond; on light
              use accentOnLight / lavenderOnLight. Opacity 30-60% behind
              content.
            </Body>
            <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
              <Verdict ok={false} size={22} />
              <Body size={15}>
                Never run text across the dense core, never stack two fields,
                never animate faster than a calm pulse.
              </Body>
            </div>
          </Panel>
        </div>
      </div>
    </Content>
  </Page>
);

/* 13 · Iconography ------------------------------------------------------- */

export const P13Icons: React.FC = () => (
  <Page n={13} section="Iconography">
    <Content
      kicker="13 · Iconography"
      title="Line icons with one pulse"
      intro="Adapted from Stellar's principles (consistent grid, single stroke weight, geometric forms) in puls3's own language: rounded strokes and exactly one halftone accent per icon."
    >
      <div style={{ display: "flex", gap: 22, height: "100%" }}>
        <Panel
          style={{
            flex: 0.9,
            alignItems: "center",
            justifyContent: "center",
            gap: 16,
          }}
        >
          <Icon name="agent" size={330} p={brandDark} grid />
          <Mono size={13}>48-unit grid · 4-unit safe margin · stroke 2.5</Mono>
        </Panel>
        <div
          style={{
            flex: 1.3,
            display: "flex",
            flexDirection: "column",
            gap: 22,
          }}
        >
          <Panel style={{ flex: 1.2, padding: 26 }}>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(6, 1fr)",
                gap: 10,
                height: "100%",
              }}
            >
              {ICONS.map((i) => (
                <div
                  key={i.name}
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                    justifyContent: "center",
                    gap: 14,
                  }}
                >
                  <Icon name={i.name} size={96} p={brandDark} />
                  <div
                    style={{ display: "flex", gap: 12, alignItems: "center" }}
                  >
                    <Icon name={i.name} size={32} p={brandDark} />
                    <Icon name={i.name} size={20} p={brandDark} />
                  </div>
                  <Mono size={13}>{i.name}</Mono>
                </div>
              ))}
            </div>
          </Panel>
          <div style={{ display: "flex", gap: 22, flex: 1 }}>
            <Panel
              bg={colors.paper}
              border={colors.hairlineLight}
              style={{
                flex: 1,
                flexDirection: "row",
                alignItems: "center",
                justifyContent: "space-around",
              }}
            >
              {ICONS.map((i) => (
                <Icon key={i.name} name={i.name} size={56} p={brandLight} />
              ))}
            </Panel>
            <Panel style={{ flex: 1, padding: 22, gap: 8 }}>
              <Label>Rules</Label>
              <Body size={15} color={colors.text}>
                Grid 48 · stroke 2.5 round caps and joins · ink strokes · one
                accent: an amber dot or a short halftone trail. No fills, no
                gradients, no second accent. Minimum size 16 px.
              </Body>
            </Panel>
          </div>
        </div>
      </div>
    </Content>
  </Page>
);

/* 14 · Applications I (digital) -------------------------------------------- */

export const AppBar: React.FC<{ p: Palette; width: number }> = ({
  p,
  width,
}) => {
  const dark = p === brandDark;
  return (
    <div
      style={{
        width,
        height: 56,
        background: dark ? colors.surface : colors.white,
        borderBottom: `1px solid ${dark ? colors.hairline : colors.hairlineLight}`,
        display: "flex",
        alignItems: "center",
        padding: "0 18px",
        gap: 28,
        boxSizing: "border-box",
      }}
    >
      <BrandLogo height={28} palette={p} />
      <span
        style={{
          fontFamily: bf.ui,
          fontWeight: 600,
          fontSize: 14,
          color: p.ink,
        }}
      >
        Studio
      </span>
      <span
        style={{
          fontFamily: bf.ui,
          fontWeight: 500,
          fontSize: 14,
          color: p.muted,
        }}
      >
        Marketplace
      </span>
      <div
        style={{
          marginLeft: "auto",
          fontFamily: bf.ui,
          fontWeight: 700,
          fontSize: 13,
          color: colors.ink,
          background:
            p.accent === colors.accent ? colors.accent : colors.accentOnLight,
          ...(p.accent !== colors.accent ? { color: colors.white } : {}),
          padding: "8px 14px",
          borderRadius: 999,
        }}
      >
        Connect wallet
      </div>
    </div>
  );
};

const AgentCard: React.FC<{ name: string; price: string }> = ({
  name,
  price,
}) => (
  <div
    style={{
      background: colors.surface,
      border: `1px solid ${colors.hairline}`,
      borderRadius: 12,
      padding: 14,
      flex: 1,
    }}
  >
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <Icon name="agent" size={28} p={brandDark} />
      <span
        style={{
          fontFamily: bf.ui,
          fontWeight: 700,
          fontSize: 14,
          color: colors.text,
        }}
      >
        {name}
      </span>
    </div>
    <div
      style={{
        fontFamily: bf.data,
        fontSize: 11,
        color: colors.muted,
        marginTop: 10,
      }}
    >
      GBZX…4KQ7
    </div>
    <div
      style={{
        fontFamily: bf.ui,
        fontWeight: 700,
        fontSize: 13,
        color: colors.accent,
        marginTop: 6,
      }}
    >
      {price}
    </div>
  </div>
);

export const P14Digital: React.FC = () => (
  <Page n={14} section="Applications · digital">
    <Content kicker="14 · Applications I · digital" title="In the product">
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1.25fr 1fr 0.55fr",
          gridTemplateRows: "0.62fr 1fr",
          gap: 18,
          height: "100%",
        }}
      >
        <Panel style={{ padding: 18, gap: 12 }}>
          <Label>Top bar · real size (56 px) · dark and light</Label>
          <div
            style={{
              borderRadius: 10,
              overflow: "hidden",
              border: `1px solid ${colors.hairline}`,
            }}
          >
            <AppBar p={brandDark} width={740} />
          </div>
          <div
            style={{
              borderRadius: 10,
              overflow: "hidden",
              border: `1px solid ${colors.hairline}`,
            }}
          >
            <AppBar p={brandLight} width={740} />
          </div>
        </Panel>
        <Panel
          bg={colors.background}
          style={{ gridRow: "1 / 3", gridColumn: 2 }}
        >
          <PulseBackground
            width={640}
            height={760}
            cx={640}
            cy={760}
            radius={430}
            step={20}
            maxR={6}
            opacity={0.4}
          />
          <div style={{ position: "relative" }}>
            <AppBar p={brandDark} width={640} />
          </div>
          <div
            style={{
              position: "relative",
              padding: "44px 34px",
              display: "flex",
              flexDirection: "column",
              gap: 18,
            }}
          >
            <Label color={colors.accent}>Landing hero</Label>
            <div
              style={{
                fontFamily: bf.display,
                fontWeight: 700,
                fontSize: 44,
                lineHeight: 1.08,
                color: colors.text,
              }}
            >
              The agent hub
              <br />
              on Stellar.
            </div>
            <Body size={16}>
              Create agents with their own wallet and identity. Hire and pay
              them in USDC.
            </Body>
            <div style={{ display: "flex", gap: 12 }}>
              <div
                style={{
                  background: colors.accent,
                  color: colors.ink,
                  fontFamily: bf.ui,
                  fontWeight: 700,
                  fontSize: 14,
                  padding: "11px 18px",
                  borderRadius: 999,
                }}
              >
                Launch Studio
              </div>
              <div
                style={{
                  border: `1px solid ${colors.hairline}`,
                  color: colors.text,
                  fontFamily: bf.ui,
                  fontWeight: 600,
                  fontSize: 14,
                  padding: "11px 18px",
                  borderRadius: 999,
                }}
              >
                Explore agents
              </div>
            </div>
            <div style={{ display: "flex", gap: 10, marginTop: 12 }}>
              <AgentCard name="Research agent" price="0.40 USDC / task" />
              <AgentCard name="Trading scout" price="1.20 USDC / task" />
            </div>
          </div>
        </Panel>
        <Panel
          bg={colors.background}
          style={{
            gridRow: "1 / 3",
            gridColumn: 3,
            alignItems: "center",
            justifyContent: "center",
            gap: 18,
          }}
        >
          <Label>Loading screen</Label>
          <div
            style={{
              width: 220,
              height: 440,
              borderRadius: 30,
              border: `2px solid ${colors.hairline}`,
              background: colors.background,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              gap: 26,
            }}
          >
            <BrandMark size={110} />
            <span
              style={{
                ...doto(900),
                fontSize: 22,
                color: colors.accent,
                letterSpacing: "0.06em",
              }}
            >
              LOADING 64%
            </span>
          </div>
        </Panel>
        <Panel
          style={{
            padding: 18,
            gap: 12,
            flexDirection: "row",
            alignItems: "center",
            justifyContent: "space-around",
          }}
        >
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 12,
            }}
          >
            <Label>Social avatar</Label>
            <div
              style={{
                width: 190,
                height: 190,
                borderRadius: "50%",
                overflow: "hidden",
                background: colors.background,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <BrandMark size={130} />
            </div>
            <Mono size={12}>circle crop · mark at 68%</Mono>
          </div>
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              gap: 12,
            }}
          >
            <Label>In a feed · 40 px</Label>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <div
                style={{
                  width: 40,
                  height: 40,
                  borderRadius: "50%",
                  background: colors.background,
                  border: `1px solid ${colors.hairline}`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <C01Small size={28} />
              </div>
              <div>
                <div
                  style={{
                    fontFamily: bf.ui,
                    fontWeight: 700,
                    fontSize: 14,
                    color: colors.text,
                  }}
                >
                  puls3
                </div>
                <Mono size={11}>@puls3xyz</Mono>
              </div>
            </div>
          </div>
        </Panel>
      </div>
    </Content>
  </Page>
);

/* 15 · Applications II ------------------------------------------------------ */

/** OG / social banner, designed at 1200 x 630 and scaled. */
export const OgBanner: React.FC<{ scale?: number }> = ({ scale = 1 }) => (
  <div
    style={{
      width: 1200 * scale,
      height: 630 * scale,
      overflow: "hidden",
      position: "relative",
    }}
  >
    <div
      style={{
        width: 1200,
        height: 630,
        transform: `scale(${scale})`,
        transformOrigin: "0 0",
        position: "relative",
        background: colors.background,
      }}
    >
      <PulseBackground
        width={1200}
        height={630}
        cx={1010}
        cy={315}
        radius={640}
        step={24}
        maxR={8}
        opacity={0.45}
      />
      <div
        style={{
          position: "absolute",
          left: 80,
          top: 90,
          display: "flex",
          flexDirection: "column",
          gap: 36,
        }}
      >
        <BrandLogo height={120} />
        <div
          style={{
            fontFamily: bf.display,
            fontWeight: 700,
            fontSize: 60,
            lineHeight: 1.08,
            color: colors.text,
          }}
        >
          The agent hub
          <br />
          on Stellar.
        </div>
        <div style={{ fontFamily: bf.ui, fontSize: 26, color: colors.muted }}>
          Create, hire and pay AI agents in USDC.
        </div>
      </div>
    </div>
  </div>
);

export const P15Print: React.FC = () => (
  <Page n={15} section="Applications · social and events">
    <Content kicker="15 · Applications II" title="Social, stage and swag">
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1.25fr 1fr",
          gridTemplateRows: "1fr 1fr",
          gap: 18,
          height: "100%",
        }}
      >
        <Panel style={{ padding: 18, gap: 10 }}>
          <Label>OG / social banner · 1200 × 630</Label>
          <div
            style={{
              borderRadius: 10,
              overflow: "hidden",
              border: `1px solid ${colors.hairline}`,
              alignSelf: "flex-start",
            }}
          >
            <OgBanner scale={0.44} />
          </div>
        </Panel>
        <Panel style={{ padding: 18, gap: 10 }}>
          <Label>Hackathon slide title</Label>
          <div
            style={{
              flex: 1,
              borderRadius: 10,
              border: `1px solid ${colors.hairline}`,
              background: colors.background,
              position: "relative",
              overflow: "hidden",
            }}
          >
            <PulseBackground
              width={620}
              height={340}
              cx={560}
              cy={40}
              radius={380}
              step={18}
              maxR={5}
              opacity={0.5}
            />
            <div style={{ position: "absolute", left: 30, top: 26 }}>
              <BrandLogo height={40} />
            </div>
            <div style={{ position: "absolute", left: 30, bottom: 30 }}>
              <div
                style={{
                  ...doto(900),
                  fontSize: 30,
                  color: colors.accent,
                  letterSpacing: "0.06em",
                }}
              >
                48H · BUILD NIGHT
              </div>
              <div
                style={{
                  fontFamily: bf.display,
                  fontWeight: 700,
                  fontSize: 40,
                  color: colors.text,
                  marginTop: 6,
                }}
              >
                Ship an agent.
              </div>
            </div>
          </div>
        </Panel>
        <Panel style={{ padding: 18, gap: 10, alignItems: "center" }}>
          <Label>Sticker · die cut</Label>
          <div
            style={{ flex: 1, display: "flex", alignItems: "center", gap: 40 }}
          >
            <div
              style={{
                width: 210,
                height: 210,
                borderRadius: "50%",
                background: colors.background,
                boxShadow: `0 0 0 8px ${colors.white}`,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                gap: 10,
              }}
            >
              <BrandMark size={100} />
              <BrandWordmark height={34} />
            </div>
            <div
              style={{
                width: 250,
                height: 130,
                borderRadius: 65,
                background: colors.paper,
                boxShadow: `0 0 0 8px ${colors.white}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <BrandLogo height={62} palette={brandLight} />
            </div>
          </div>
        </Panel>
        <Panel style={{ padding: 18, gap: 10, alignItems: "center" }}>
          <Label>Event badge · Doto accent</Label>
          <div
            style={{
              height: 300,
              width: 220,
              borderRadius: 18,
              background: colors.background,
              border: `1px solid ${colors.hairline}`,
              position: "relative",
              overflow: "hidden",
              padding: 20,
              display: "flex",
              flexDirection: "column",
              gap: 8,
            }}
          >
            <PulseBackground
              width={230}
              height={330}
              cx={230}
              cy={0}
              radius={220}
              step={14}
              maxR={4}
              opacity={0.5}
            />
            <div style={{ position: "relative" }}>
              <BrandLogo height={26} />
            </div>
            <div style={{ position: "relative", marginTop: "auto" }}>
              <div style={{ ...doto(900), fontSize: 30, color: colors.accent }}>
                AGENT 042
              </div>
              <div
                style={{
                  fontFamily: bf.ui,
                  fontWeight: 700,
                  fontSize: 18,
                  color: colors.text,
                }}
              >
                Ana Rojas
              </div>
              <Mono size={11}>builder · stellar hack/3</Mono>
            </div>
          </div>
        </Panel>
      </div>
    </Content>
  </Page>
);

/* 16 · Co-branding ------------------------------------------------------- */

const BuiltOn: React.FC<{ light?: boolean; height: number }> = ({
  light = false,
  height,
}) => (
  <div style={{ display: "flex", alignItems: "center", gap: height * 0.3 }}>
    <BrandLogo height={height} palette={light ? brandLight : brandDark} />
    <div
      style={{
        width: 1.5,
        height: height * 0.8,
        background: light ? colors.hairlineLight : colors.hairline,
      }}
    />
    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      <span
        style={{
          fontFamily: bf.ui,
          fontWeight: 600,
          fontSize: Math.max(11, height * 0.13),
          color: light ? colors.mutedOnLight : colors.muted,
        }}
      >
        Built on
      </span>
      <Placeholder
        w={height * 1.9}
        h={height * 0.5}
        label="official Stellar logo, from the SDF brand kit"
        light={light}
      />
    </div>
  </div>
);

export const P16CoBrand: React.FC = () => (
  <Page n={16} section="Co-branding">
    <Content
      kicker="16 · Co-branding with Stellar"
      title="Built on Stellar"
      intro="Use only the official Stellar logo from the SDF brand kit, unaltered. The box below is a placeholder: never redraw, recolor or imitate the Stellar logo."
    >
      <div style={{ display: "flex", gap: 22, height: "100%" }}>
        <div
          style={{
            flex: 1.4,
            display: "flex",
            flexDirection: "column",
            gap: 22,
          }}
        >
          <Panel
            bg={colors.background}
            style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
          >
            <BuiltOn height={120} />
          </Panel>
          <Panel
            bg={colors.paper}
            border={colors.hairlineLight}
            style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
          >
            <BuiltOn height={120} light />
          </Panel>
        </div>
        <Panel style={{ flex: 1, padding: 30, gap: 16 }}>
          <Label>Placement and spacing</Label>
          {[
            "puls3 always comes first (left or top); Stellar follows as the platform.",
            "Separate the two with a 1.5 px hairline centered in a gap of 0.3 × puls3 mark height on each side.",
            'The Stellar logo is set at 0.5 × the puls3 mark height, under a small "Built on" label (Manrope 600).',
            "Keep the clear space of both logos (puls3: 4c). No other element between or around them.",
            "Never merge the two marks, never reuse Stellar yellow in puls3 elements, never place the Stellar logo on the halftone core.",
          ].map((r, i) => (
            <div key={i} style={{ display: "flex", gap: 12 }}>
              <Mono size={14} color={colors.accent}>
                {String(i + 1).padStart(2, "0")}
              </Mono>
              <Body size={16} color={colors.text}>
                {r}
              </Body>
            </div>
          ))}
          <div style={{ marginTop: "auto" }}>
            <H2 size={16} color={colors.muted}>
              Asset status: pending the official SVG from the SDF brand kit.
            </H2>
          </div>
        </Panel>
      </div>
    </Content>
  </Page>
);
