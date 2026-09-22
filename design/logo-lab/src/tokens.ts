/**
 * puls3 brand tokens. Inspired by (not copied from) the Stellar 2026 guidelines.
 * This is the ONLY file allowed to contain raw color values.
 */

export const colors = {
  background: "#0B0B0D",
  surface: "#16161A",
  text: "#F6F7F8",
  muted: "#A3A3AD",
  accent: "#FFB547", // amber
  lavender: "#A99CF2",
  success: "#2BD4A0",
  // Deeper variants used only on light backgrounds, to keep small marks legible.
  ink: "#0B0B0D",
  paper: "#F6F7F8",
  accentDeep: "#D98A12",
  lavenderDeep: "#6E5DD3",
  hairline: "#2A2A31",
  hairlineLight: "#D9DAE0",
  // Mock browser / app chrome used by the round-3 context sheets.
  chromeDark: "#1E1E24",
  chromeLight: "#E4E5EA",
  white: "#FFFFFF",
  // Brand guide 2026: on-light variants, tuned for WCAG contrast on paper (#F6F7F8).
  // Solid text (e.g. the solid "3") >= 4.5:1, graphic elements (halftone dots) >= 3:1.
  accentOnLight: "#A05F00",
  lavenderOnLight: "#6352CC",
  mutedOnLight: "#5E5E6A",
  // Guide annotations only (misuse crosses, "do" ticks).
  danger: "#FF5C5C",
  shadow: "#000000",
} as const;

export const fonts = {
  display: "'Instrument Serif', Georgia, serif",
  sans: "Manrope, 'Helvetica Neue', Arial, sans-serif",
  mono: "'JetBrains Mono', Consolas, monospace",
} as const;

/** Colors a mark or lockup is drawn with. Swapped for dark vs light backgrounds. */
export type Palette = {
  bg: string;
  ink: string; // primary strokes and wordmark
  accent: string; // amber highlights
  secondary: string; // lavender
  muted: string;
};

export const darkPalette: Palette = {
  bg: colors.background,
  ink: colors.text,
  accent: colors.accent,
  secondary: colors.lavender,
  muted: colors.muted,
};

export const lightPalette: Palette = {
  bg: colors.paper,
  ink: colors.ink,
  accent: colors.accentDeep,
  secondary: colors.lavenderDeep,
  muted: colors.muted,
};

/** Official brand palettes (brand guide 2026). */
export const brandDark: Palette = darkPalette;

export const brandLight: Palette = {
  bg: colors.paper,
  ink: colors.ink,
  accent: colors.accentOnLight,
  secondary: colors.lavenderOnLight,
  muted: colors.mutedOnLight,
};

export const monoWhite: Palette = {
  bg: colors.background,
  ink: colors.text,
  accent: colors.text,
  secondary: colors.text,
  muted: colors.text,
};

export const monoInk: Palette = {
  bg: colors.paper,
  ink: colors.ink,
  accent: colors.ink,
  secondary: colors.ink,
  muted: colors.ink,
};

export const video = {
  width: 1920,
  height: 1080,
  fps: 30,
  conceptFrames: 120, // ~4 s per concept
  shuffleSegment: 90, // ~3 s per concept in the reel
} as const;

/** Marks are drawn on a 128-unit grid (a nod to the 128 px icon grid). */
export const GRID = 128;
