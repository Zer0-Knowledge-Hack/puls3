import type React from "react";
import type { Palette } from "../tokens";

/** Artwork drawn inside a 128x128 grid. `t` is reveal progress 0..1 (1 = final static mark). */
export type ArtProps = { t: number; p: Palette };

export type MarkProps = { size: number; t?: number; palette?: Palette };

export type LockupProps = {
  height: number;
  markT?: number; // reveal progress of the symbol part
  wordT?: number; // reveal progress of the wordmark part
  palette?: Palette;
};

export type Concept = {
  code: string; // "C01"
  slug: string; // "HalftonePulse"
  name: string; // "Halftone Pulse"
  mark: string; // one-line description of the mark
  rationale: string; // one-line rationale shown in the caption
  Mark: React.FC<MarkProps>;
  Lockup: React.FC<LockupProps>;
  /** Lockup viewBox size in lockup units. */
  lockupSize: { w: number; h: number };
  /**
   * "slide": the big mark slides left into the lockup while the wordmark appears.
   * "self": the concept IS the wordmark, so the scene cross-fades from mark to lockup.
   */
  lockupMode: "slide" | "self";
  /** x of the mark center inside the lockup (lockup units). Used by "slide". */
  markCenterX: number;
};
