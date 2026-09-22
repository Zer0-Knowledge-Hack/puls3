import React from "react";
import { darkPalette, GRID } from "../tokens";
import type {
  ArtProps,
  Concept,
  LockupProps,
  MarkProps,
} from "../concepts/types";
import * as M from "./marks";
import {
  typeSpec,
  wordmarkWidthEm,
  Wordmark2,
  type FontKey,
  type Treatment,
  type TypeSpec,
} from "./type";

const SVG_NS = "http://www.w3.org/2000/svg";

export type RMarkProps = MarkProps & {
  /** "auto" switches to the simplified art at 40 px and below. */
  variant?: "auto" | "full" | "small";
};

export const makeRMark = (
  Art: React.FC<ArtProps>,
  SmallArt: React.FC<ArtProps> | undefined,
  label: string,
): React.FC<RMarkProps> => {
  const Mark: React.FC<RMarkProps> = ({
    size,
    t = 1,
    palette = darkPalette,
    variant = "auto",
  }) => {
    const small =
      SmallArt && (variant === "small" || (variant === "auto" && size <= 40));
    const A = small ? SmallArt : Art;
    return (
      <svg
        xmlns={SVG_NS}
        width={size}
        height={size}
        viewBox={`0 0 ${GRID} ${GRID}`}
        role="img"
        aria-label={`puls3 ${label} mark${small ? " (small)" : ""}`}
      >
        <A t={t} p={palette} />
      </svg>
    );
  };
  Mark.displayName = `${label.replace(/\W/g, "")}Mark`;
  return Mark;
};

/* ---------------------------- Lockups ------------------------------ */

const MARK_X = 16;
const GAP = 34;
const H = 160;

/** Font size giving the wordmark an optical height that balances a 128-unit mark. */
const lockupFontSize = (s: TypeSpec, tr: Treatment) =>
  tr === 2 ? 40 / s.capHeight : 52 / s.xHeight;

export const rLockupSize = (s: TypeSpec, tr: Treatment) => {
  const size = lockupFontSize(s, tr);
  return { w: MARK_X + GRID + GAP + wordmarkWidthEm(s, tr) * size + 16, h: H };
};

export const makeRLockup = (
  Art: React.FC<ArtProps>,
  label: string,
  font: FontKey,
  treatment: Treatment,
): React.FC<LockupProps> => {
  const spec = typeSpec(font);
  const { w } = rLockupSize(spec, treatment);
  const size = lockupFontSize(spec, treatment);
  const visible = treatment === 2 ? spec.capHeight : spec.xHeight;
  const baseline = H / 2 + (visible * size) / 2;
  const Lockup: React.FC<LockupProps> = ({
    height,
    markT = 1,
    wordT = 1,
    palette = darkPalette,
  }) => (
    <svg
      xmlns={SVG_NS}
      height={height}
      width={(height * w) / H}
      viewBox={`0 0 ${w.toFixed(1)} ${H}`}
      role="img"
      aria-label={`puls3 ${label} lockup in ${spec.label}`}
    >
      <g transform={`translate(${MARK_X} 16)`}>
        <Art t={markT} p={palette} />
      </g>
      <Wordmark2
        spec={spec}
        treatment={treatment}
        x={MARK_X + GRID + GAP}
        y={baseline}
        size={size}
        p={palette}
        t={wordT}
      />
    </svg>
  );
  Lockup.displayName = `${label.replace(/\W/g, "")}Lockup${spec.key}`;
  return Lockup;
};

/* --------------------------- Registry ------------------------------ */

/** Top font pick from the typography study, used by the R01..R08 reveals. */
export const TOP_FONT: FontKey = "Unbounded";
export const TOP_TREATMENT: Treatment = 1;

export type RConcept = Concept & {
  Art: React.FC<ArtProps>;
  SmallArt?: React.FC<ArtProps>;
  RMark: React.FC<RMarkProps>;
};

const def = (
  code: string,
  slug: string,
  name: string,
  mark: string,
  rationale: string,
  Art: React.FC<ArtProps>,
  SmallArt?: React.FC<ArtProps>,
): RConcept => {
  const RMark = makeRMark(Art, SmallArt, name);
  const size = rLockupSize(typeSpec(TOP_FONT), TOP_TREATMENT);
  return {
    code,
    slug,
    name,
    mark,
    rationale,
    Art,
    SmallArt,
    RMark,
    Mark: RMark,
    Lockup: makeRLockup(Art, name, TOP_FONT, TOP_TREATMENT),
    lockupSize: size,
    lockupMode: "slide",
    markCenterX: MARK_X + GRID / 2,
  };
};

export const R_CONCEPTS: RConcept[] = [
  def(
    "R01",
    "HalftonePlanet",
    "Halftone Planet",
    "A sphere shaded purely by halftone dot size, lit from the upper left.",
    "C01's dot field becomes a world: depth and light with a print-dot texture.",
    M.R01Art,
    M.R01Small,
  ),
  def(
    "R02",
    "PulseRing",
    "Halftone Pulse + Ring",
    "C01's swelling halftone core inside one broken signal ring.",
    "The heartbeat plus its broadcast: a live agent on the network.",
    M.R02Art,
    M.R02Small,
  ),
  def(
    "R03",
    "EclipsePulse",
    "Eclipse Pulse",
    "A halftone disc eclipsing an amber sun, leaving a crescent corona.",
    "Atmospheric and cosmic: the signal glows around the edge of the unknown.",
    M.R03Art,
    M.R03Small,
  ),
  def(
    "R04",
    "SignalRingsV2",
    "Signal Rings v2",
    "C04 refined: a halftone core emitting two rings with offset gaps.",
    "Broadcast, discoverable, always on; the gaps rotate, never forming a band.",
    M.R04Art,
    M.R04Small,
  ),
  def(
    "R05",
    "PulseOrbit",
    "Pulse Orbit",
    "A halftone core circled by one tilted orbit and an amber satellite.",
    "An agent in orbit around the hub; one ellipse, never crossing the core.",
    M.R05Art,
    M.R05Small,
  ),
  def(
    "R06",
    "HalftonePV2",
    "Halftone p v2",
    "C07 rebuilt with fewer, larger dots and a round bowl holding the pulse.",
    "A monogram that survives favicon sizes while keeping the halftone voice.",
    M.R06Art,
    M.R06Small,
  ),
  def(
    "R07",
    "PSignal",
    "p Signal",
    "A p whose bowl is a pair of broken signal rings around an amber node.",
    "Letter and broadcast in one: the p is literally transmitting.",
    M.R07Art,
    M.R07Small,
  ),
  def(
    "R08",
    "PPlanet",
    "p Planet",
    "A p whose bowl is a halftone-shaded planet with a tiny orbiting moon.",
    "The brand letter as a small world in the Stellar universe.",
    M.R08Art,
    M.R08Small,
  ),
];

export const rConcept = (code: string) =>
  R_CONCEPTS.find((c) => c.code === code) ?? R_CONCEPTS[0];
