import { loadFont as loadDoto } from "@remotion/google-fonts/Doto";
import { loadFont as loadSora } from "@remotion/google-fonts/Sora";
import { loadFont as loadUnbounded } from "@remotion/google-fonts/Unbounded";
import { loadFont as loadTektur } from "@remotion/google-fonts/Tektur";
import { loadFont as loadZenDots } from "@remotion/google-fonts/ZenDots";
import { loadFont as loadAudiowide } from "@remotion/google-fonts/Audiowide";
import { loadFont as loadQuantico } from "@remotion/google-fonts/Quantico";
import { loadFont as loadElectrolize } from "@remotion/google-fonts/Electrolize";
import { loadFont as loadMichroma } from "@remotion/google-fonts/Michroma";
import { loadFont as loadLexendGiga } from "@remotion/google-fonts/LexendGiga";
import { loadFont as loadSyncopate } from "@remotion/google-fonts/Syncopate";

// Round-3 live fonts. Listed in package.json "sideEffects" so the bundler keeps this module.
const latin = { subsets: ["latin" as const] };
loadDoto("normal", { weights: ["500", "900"], ...latin });
loadSora("normal", { weights: ["600", "700"], ...latin });
loadUnbounded("normal", { weights: ["200", "300", "700"], ...latin });
loadTektur("normal", { weights: ["500"], ...latin });
loadZenDots("normal", { weights: ["400"], ...latin });
loadAudiowide("normal", { weights: ["400"], ...latin });
loadQuantico("normal", { weights: ["700"], ...latin });
loadElectrolize("normal", { weights: ["400"], ...latin });
loadMichroma("normal", { weights: ["400"], ...latin });
loadLexendGiga("normal", { weights: ["300"], ...latin });
loadSyncopate("normal", { weights: ["400"], ...latin });
