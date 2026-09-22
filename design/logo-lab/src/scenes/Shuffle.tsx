import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { CONCEPTS } from "../concepts";
import { colors, video } from "../tokens";
import { ConceptScene } from "./ConceptScene";

/** The "barajar" reel: every concept back to back, ~3 s each. */
export const Shuffle: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: colors.background }}>
    {CONCEPTS.map((concept, i) => (
      <Sequence
        key={concept.code}
        from={i * video.shuffleSegment}
        durationInFrames={video.shuffleSegment}
        name={`${concept.code} ${concept.name}`}
      >
        <ConceptScene
          concept={concept}
          duration={video.shuffleSegment}
          reel={{ index: i, total: CONCEPTS.length }}
        />
      </Sequence>
    ))}
  </AbsoluteFill>
);
