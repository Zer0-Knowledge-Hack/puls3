import "./fonts";
import React from "react";
import { Composition, Folder, Still } from "remotion";
import { CONCEPTS } from "./concepts";
import { ConceptScene } from "./scenes/ConceptScene";
import { ContactSheet, ContactSheetMarks } from "./scenes/ContactSheet";
import { Shuffle } from "./scenes/Shuffle";
import { video } from "./tokens";
import { Round2Compositions } from "./round2/Round2";
import { Round3Compositions } from "./round3/Round3";
import { BrandGuideCompositions } from "./brand/BrandGuide";

const ConceptComposition: React.FC<{ code: string }> = ({ code }) => {
  const concept = CONCEPTS.find((c) => c.code === code) ?? CONCEPTS[0];
  return <ConceptScene concept={concept} duration={video.conceptFrames} />;
};

export const RemotionRoot: React.FC = () => {
  const common = { width: video.width, height: video.height, fps: video.fps };
  return (
    <>
      <Folder name="Concepts">
        {CONCEPTS.map((concept) => (
          <Composition
            key={concept.code}
            id={`${concept.code}-${concept.slug}`}
            component={ConceptComposition}
            defaultProps={{ code: concept.code }}
            durationInFrames={video.conceptFrames}
            {...common}
          />
        ))}
      </Folder>
      <Composition
        id="Shuffle"
        component={Shuffle}
        durationInFrames={video.shuffleSegment * CONCEPTS.length}
        {...common}
      />
      <Still
        id="ContactSheet"
        component={ContactSheet}
        width={video.width}
        height={video.height}
      />
      <Still
        id="ContactSheetMarks"
        component={ContactSheetMarks}
        width={video.width}
        height={video.height}
      />
      <Round2Compositions />
      <Round3Compositions />
      <BrandGuideCompositions />
    </>
  );
};
