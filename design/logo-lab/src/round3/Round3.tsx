import "./fonts";
import React from "react";
import { Composition, Folder, Still } from "remotion";
import { video } from "../tokens";
import { Reveal3, Shuffle3 } from "./reveal";
import {
  FINALISTS,
  R3C01Small,
  R3DirA,
  R3DirB,
  R3DirC,
  R3DirD,
  R3Finalists,
} from "./sheets";

/** All round-3 compositions (C01 mark locked; wordmark typography study). */
export const Round3Compositions: React.FC = () => {
  const size = { width: video.width, height: video.height };
  return (
    <Folder name="Round3">
      <Still id="R3-C01Small" component={R3C01Small} {...size} />
      <Still id="R3-DirA" component={R3DirA} {...size} />
      <Still id="R3-DirB" component={R3DirB} {...size} />
      <Still id="R3-DirC" component={R3DirC} {...size} />
      <Still id="R3-DirD" component={R3DirD} {...size} />
      <Still id="R3-Finalists" component={R3Finalists} {...size} />
      {FINALISTS.map((f) => (
        <Composition
          key={f.id}
          id={`R3-Reveal-${f.id}`}
          component={Reveal3}
          defaultProps={{ id: f.id }}
          durationInFrames={video.conceptFrames}
          fps={video.fps}
          {...size}
        />
      ))}
      <Composition
        id="Shuffle3"
        component={Shuffle3}
        durationInFrames={video.shuffleSegment * FINALISTS.length}
        fps={video.fps}
        {...size}
      />
    </Folder>
  );
};
