import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import type { Concept } from "../concepts";
import { colors } from "../tokens";
import { Backdrop, MonoLabel } from "./Chrome";

const LOCKUP_WIDTH_PX = 900; // on-screen width of the settled lockup
const MARK_INTRO_SCALE = 1.9; // how large the mark starts before settling into the lockup

type Props = {
  concept: Concept;
  /** Scene length in frames. Timings are proportional, so the same scene works at 4 s or 3 s. */
  duration: number;
  /** Shuffle reel mode: shows the number badge and fades at both ends. */
  reel?: { index: number; total: number };
};

export const ConceptScene: React.FC<Props> = ({
  concept,
  duration: D,
  reel,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const clamp = {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  } as const;

  const markT = interpolate(frame, [0.04 * D, 0.5 * D], [0, 1], {
    ...clamp,
    easing: Easing.inOut(Easing.quad),
  });
  const settle = spring({
    frame: frame - Math.round(0.5 * D),
    fps,
    config: { damping: 200 },
    durationInFrames: Math.round(0.25 * D),
  });
  const wordT = interpolate(frame, [0.55 * D, 0.8 * D], [0, 1], clamp);
  const captionIn = interpolate(frame, [0.62 * D, 0.8 * D], [0, 1], clamp);

  // Reel transitions: quick fade/zoom in and out at segment edges.
  const fadeIn = reel ? interpolate(frame, [0, 7], [0, 1], clamp) : 1;
  const fadeOut = reel ? interpolate(frame, [D - 6, D], [1, 0], clamp) : 1;
  const sceneOpacity = Math.min(fadeIn, fadeOut);
  const sceneScale = reel ? 0.985 + 0.015 * fadeIn : 1;

  const { w, h } = concept.lockupSize;
  const lockupH = (LOCKUP_WIDTH_PX * h) / w;
  const markPx = (concept.markCenterX / w) * LOCKUP_WIDTH_PX;

  let stage: React.ReactNode;
  if (concept.lockupMode === "slide") {
    const offset = (LOCKUP_WIDTH_PX / 2 - markPx) * (1 - settle);
    const scale = 1 + (MARK_INTRO_SCALE - 1) * (1 - settle);
    stage = (
      <div
        style={{
          width: LOCKUP_WIDTH_PX,
          height: lockupH,
          transformOrigin: `${markPx}px ${lockupH / 2}px`,
          transform: `translateX(${offset}px) scale(${scale})`,
        }}
      >
        <concept.Lockup height={lockupH} markT={markT} wordT={wordT} />
      </div>
    );
  } else {
    // Wordmark concepts: reveal the standalone mark, then cross-fade into the wordmark lockup.
    const markSize = 360;
    const lockupMarkT = interpolate(frame, [0.6 * D, 0.9 * D], [0, 1], clamp);
    stage = (
      <div
        style={{
          position: "relative",
          width: LOCKUP_WIDTH_PX,
          height: Math.max(lockupH, markSize),
        }}
      >
        <AbsoluteFill
          style={{
            alignItems: "center",
            justifyContent: "center",
            opacity: 1 - settle,
            transform: `scale(${1 - 0.15 * settle})`,
          }}
        >
          <concept.Mark size={markSize} t={markT} />
        </AbsoluteFill>
        <AbsoluteFill
          style={{
            alignItems: "center",
            justifyContent: "center",
            opacity: settle,
          }}
        >
          <concept.Lockup height={lockupH} markT={lockupMarkT} wordT={wordT} />
        </AbsoluteFill>
      </div>
    );
  }

  return (
    <Backdrop>
      <AbsoluteFill
        style={{ opacity: sceneOpacity, transform: `scale(${sceneScale})` }}
      >
        <AbsoluteFill
          style={{
            padding: "56px 72px",
            justifyContent: "space-between",
            flexDirection: "row",
          }}
        >
          <MonoLabel size={20}>puls3 / logo lab</MonoLabel>
          {reel ? (
            <MonoLabel size={20} color={colors.text}>
              {String(reel.index + 1).padStart(2, "0")} /{" "}
              {String(reel.total).padStart(2, "0")}
              <span style={{ color: colors.accent }}>
                {"  "}
                {concept.name.toUpperCase()}
              </span>
            </MonoLabel>
          ) : (
            <MonoLabel size={20}>{concept.code}</MonoLabel>
          )}
        </AbsoluteFill>
        <AbsoluteFill
          style={{
            alignItems: "center",
            justifyContent: "center",
            paddingBottom: 60,
          }}
        >
          {stage}
        </AbsoluteFill>
        <AbsoluteFill
          style={{
            justifyContent: "flex-end",
            alignItems: "center",
            paddingBottom: 72,
            opacity: captionIn,
            transform: `translateY(${(1 - captionIn) * 8}px)`,
          }}
        >
          <MonoLabel size={24} color={colors.text}>
            {concept.code} · {concept.name}
          </MonoLabel>
          <MonoLabel size={20} style={{ marginTop: 12 }}>
            {concept.rationale}
          </MonoLabel>
        </AbsoluteFill>
      </AbsoluteFill>
    </Backdrop>
  );
};
