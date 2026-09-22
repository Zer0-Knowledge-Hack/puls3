import { loadFont as loadInstrumentSerif } from "@remotion/google-fonts/InstrumentSerif";
import { loadFont as loadManrope } from "@remotion/google-fonts/Manrope";
import { loadFont as loadJetBrainsMono } from "@remotion/google-fonts/JetBrainsMono";

// Loaded once when the Remotion bundle boots. Components refer to the
// family names declared in tokens.ts, so they stay renderable outside Remotion.
loadInstrumentSerif("normal", { weights: ["400"], subsets: ["latin"] });
loadManrope("normal", { weights: ["500", "700", "800"], subsets: ["latin"] });
loadJetBrainsMono("normal", { weights: ["400", "500"], subsets: ["latin"] });
