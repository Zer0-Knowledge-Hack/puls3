import React from "react";
import { AbsoluteFill, Sequence } from "remotion";
import { colors, video } from "../tokens";
import { ConceptScene } from "../scenes/ConceptScene";
import { rConcept, R_CONCEPTS } from "./concepts";

/** Round-2 "barajar" reel: R01..R08 back to back, ~3 s each. */
export const Shuffle2: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: colors.background }}>
    {R_CONCEPTS.map((concept, i) => (
      <Sequence
        key={concept.code}
        from={i * video.shuffleSegment}
        durationInFrames={video.shuffleSegment}
        name={`${concept.code} ${concept.name}`}
      >
        <ConceptScene
          concept={concept}
          duration={video.shuffleSegment}
          reel={{ index: i, total: R_CONCEPTS.length }}
        />
      </Sequence>
    ))}
  </AbsoluteFill>
);

/** One ~4 s reveal per round-2 mark, ending in a lockup with the top font pick. */
export const RConceptComposition: React.FC<{ code: string }> = ({ code }) => (
  <ConceptScene concept={rConcept(code)} duration={video.conceptFrames} />
);
