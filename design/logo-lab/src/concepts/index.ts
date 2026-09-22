import { HalftonePulse } from "./c01-halftone-pulse";
import { Heartbeat3 } from "./c02-heartbeat-3";
import { Orbit3 } from "./c03-orbit-3";
import { SignalRings } from "./c04-signal-rings";
import { Constellation } from "./c05-constellation";
import { HighlightWordmark } from "./c06-highlight-wordmark";
import { HalftoneP } from "./c07-halftone-p";
import { WaveWordmark } from "./c08-wave-wordmark";
import type { Concept } from "./types";

export const CONCEPTS: Concept[] = [
  HalftonePulse,
  Heartbeat3,
  Orbit3,
  SignalRings,
  Constellation,
  HighlightWordmark,
  HalftoneP,
  WaveWordmark,
];

export type { Concept } from "./types";
