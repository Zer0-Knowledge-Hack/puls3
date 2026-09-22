import "./fonts";
import React from "react";
import { Composition, Folder, Still } from "remotion";
import { video } from "../tokens";
import { R_CONCEPTS } from "./concepts";
import { RLockups, RMarks, RMarksSmall, RTypeSheet } from "./sheets";
import { RConceptComposition, Shuffle2 } from "./Shuffle2";

/** All round-2 compositions, mounted from Root next to the untouched round-1 set. */
export const Round2Compositions: React.FC = () => {
  const size = { width: video.width, height: video.height };
  return (
    <Folder name="Round2">
      <Still id="R-Marks" component={RMarks} {...size} />
      <Still id="R-MarksSmall" component={RMarksSmall} {...size} />
      <Still id="R-TypeSheet" component={RTypeSheet} {...size} />
      <Still id="R-Lockups" component={RLockups} {...size} />
      {R_CONCEPTS.map((c) => (
        <Composition
          key={c.code}
          id={`${c.code}-${c.slug}`}
          component={RConceptComposition}
          defaultProps={{ code: c.code }}
          durationInFrames={video.conceptFrames}
          fps={video.fps}
          {...size}
        />
      ))}
      <Composition
        id="Shuffle2"
        component={Shuffle2}
        durationInFrames={video.shuffleSegment * R_CONCEPTS.length}
        fps={video.fps}
        {...size}
      />
    </Folder>
  );
};
