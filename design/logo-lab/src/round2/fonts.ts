import { loadFont as loadUnbounded } from "@remotion/google-fonts/Unbounded";
import { loadFont as loadMichroma } from "@remotion/google-fonts/Michroma";
import { loadFont as loadSyncopate } from "@remotion/google-fonts/Syncopate";
import { loadFont as loadKronaOne } from "@remotion/google-fonts/KronaOne";
import { loadFont as loadSora } from "@remotion/google-fonts/Sora";
import { loadFont as loadLexendZetta } from "@remotion/google-fonts/LexendZetta";
import { loadFont as loadSpaceGrotesk } from "@remotion/google-fonts/SpaceGrotesk";
import { loadFont as loadOrbitron } from "@remotion/google-fonts/Orbitron";

// Round-2 wordmark candidates. Weights match TYPE_SPECS in ./type.tsx.
const latin = { subsets: ["latin" as const] };
loadUnbounded("normal", { weights: ["500"], ...latin });
loadMichroma("normal", { weights: ["400"], ...latin });
loadSyncopate("normal", { weights: ["700"], ...latin });
loadKronaOne("normal", { weights: ["400"], ...latin });
loadSora("normal", { weights: ["600"], ...latin });
loadLexendZetta("normal", { weights: ["500"], ...latin });
loadSpaceGrotesk("normal", { weights: ["500"], ...latin });
loadOrbitron("normal", { weights: ["700"], ...latin });
