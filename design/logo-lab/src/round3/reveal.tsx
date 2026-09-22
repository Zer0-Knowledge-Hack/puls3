import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { colors, video } from "../tokens";
import { Backdrop, MonoLabel } from "../scenes/Chrome";
import { lockupGeometry, LockupSvg } from "./lockup";
import { option } from "./options";
import { FINALISTS } from "./sheets";

const LOCKUP_W = 1000; // on-screen width of the settled lockup (px)

/**
 * Finalist reveal: C01 pulses in at the center (dots swell from the core), then slides
 * into the lockup while the wordmark resolves (dot wordmarks assemble out of the pulse).
 */
export const Reveal3: React.FC<{
  id: string;
  duration?: number;
  reel?: { index: number; total: number };
}> = ({ id, duration: D = video.conceptFrames, reel }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const clamp = {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  } as const;
  const o = option(id);
  const g = lockupGeometry(o);
  const markPx = (LOCKUP_W * 128) / (g.w + 6);
  const scalePx = markPx / 128;
  const lockupW = (g.w + 6) * scalePx;
  const markCenter = (64 + 6) * scalePx;

  const markT = interpolate(frame, [0.03 * D, 0.45 * D], [0, 1], {
    ...clamp,
    easing: Easing.inOut(Easing.quad),
  });
  const settle = spring({
    frame: frame - Math.round(0.42 * D),
    fps,
    config: { damping: 200 },
    durationInFrames: Math.round(0.25 * D),
  });
  const wordT = interpolate(frame, [0.48 * D, 0.85 * D], [0, 1], clamp);
  const captionIn = interpolate(frame, [0.65 * D, 0.82 * D], [0, 1], clamp);
  const fade = reel
    ? Math.min(
        interpolate(frame, [0, 7], [0, 1], clamp),
        interpolate(frame, [D - 6, D], [1, 0], clamp),
      )
    : 1;

  const offset = (lockupW / 2 - markCenter) * (1 - settle);
  const scale = 1 + 0.8 * (1 - settle);
  const finalist = FINALISTS.find((f) => f.id === id);

  return (
    <Backdrop>
      <AbsoluteFill style={{ opacity: fade }}>
        <AbsoluteFill
          style={{
            padding: "56px 72px",
            flexDirection: "row",
            justifyContent: "space-between",
          }}
        >
          <MonoLabel>puls3 / logo lab / round 3</MonoLabel>
          <MonoLabel color={colors.text}>
            {reel
              ? `${String(reel.index + 1).padStart(2, "0")} / ${String(reel.total).padStart(2, "0")}  `
              : ""}
            <span style={{ color: colors.accent }}>
              {o.id} · {o.font.toUpperCase()} {o.weight}
            </span>
          </MonoLabel>
        </AbsoluteFill>
        <AbsoluteFill
          style={{
            alignItems: "center",
            justifyContent: "center",
            paddingBottom: 60,
          }}
        >
          <div
            style={{
              transformOrigin: `${markCenter}px 50%`,
              transform: `translateX(${offset}px) scale(${scale})`,
            }}
          >
            <LockupSvg opt={o} height={markPx} markT={markT} wordT={wordT} />
          </div>
        </AbsoluteFill>
        <AbsoluteFill
          style={{
            justifyContent: "flex-end",
            alignItems: "center",
            paddingBottom: 72,
            opacity: captionIn,
          }}
        >
          <MonoLabel size={24} color={colors.text}>
            {o.id} · {o.font} {o.weight} · {o.treatment}
          </MonoLabel>
          <MonoLabel size={20} style={{ marginTop: 12 }}>
            {finalist?.rationale ?? o.note}
          </MonoLabel>
        </AbsoluteFill>
      </AbsoluteFill>
    </Backdrop>
  );
};

export const Shuffle3: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: colors.background }}>
    {FINALISTS.map((f, i) => (
      <Sequence
        key={f.id}
        from={i * video.shuffleSegment}
        durationInFrames={video.shuffleSegment}
        name={f.id}
      >
        <Reveal3
          id={f.id}
          duration={video.shuffleSegment}
          reel={{ index: i, total: FINALISTS.length }}
        />
      </Sequence>
    ))}
  </AbsoluteFill>
);
