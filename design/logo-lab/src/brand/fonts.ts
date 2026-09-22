import { continueRender, delayRender, staticFile } from "remotion";
import { loadFont as loadUnbounded } from "@remotion/google-fonts/Unbounded";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";
import { loadFont as loadJetBrainsMono } from "@remotion/google-fonts/JetBrainsMono";

// Brand guide fonts. Listed in package.json "sideEffects" so the bundler keeps this module.
const latin = { subsets: ["latin" as const] };
loadUnbounded("normal", { weights: ["400", "500", "700"], ...latin });
loadManrope("normal", {
  weights: ["400", "500", "600", "700", "800"],
  ...latin,
});
loadJetBrainsMono("normal", { weights: ["400", "500", "700"], ...latin });

/**
 * Doto is self-hosted (assets/brand/fonts) because the Google Fonts web API cannot set
 * the ROND axis. Use it with font-variation-settings: "'ROND' 100".
 */
export const DOTO_FAMILY = "Doto ROND";

if (typeof document !== "undefined") {
  const handle = delayRender("Loading self-hosted Doto (ROND axis)");
  const face = new FontFace(
    DOTO_FAMILY,
    `url(${staticFile("fonts/Doto-ROND-wght.ttf")}) format("truetype")`,
    {
      weight: "100 900",
    },
  );
  face
    .load()
    .then((loaded) => {
      document.fonts.add(loaded);
      continueRender(handle);
    })
    .catch((err) => {
      console.error("Doto failed to load", err);
      continueRender(handle);
    });
}
