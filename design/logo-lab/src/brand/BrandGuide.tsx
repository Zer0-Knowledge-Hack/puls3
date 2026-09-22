import "./fonts";
import React from "react";
import { Folder, Still } from "remotion";
import { video } from "../tokens";
import { AvatarAsset, FaviconAsset, OgAsset } from "./assets";
import {
  P01Cover,
  P02Essence,
  P03Primary,
  P04Anatomy,
  P05Versions,
  P06SizeRules,
} from "./pages/pages1";
import {
  P07ClearSpace,
  P08Misuse,
  P09ColorDark,
  P10ColorLight,
  P11Typography,
} from "./pages/pages2";
import {
  P12Motif,
  P13Icons,
  P14Digital,
  P15Print,
  P16CoBrand,
} from "./pages/pages3";

/** Guide pages in order; ids are BG-NN-<slug>, rendered to docs/brand/pages/NN-<slug>.png. */
export const PAGES: { slug: string; C: React.FC }[] = [
  { slug: "cover", C: P01Cover },
  { slug: "brand-essence", C: P02Essence },
  { slug: "primary-logo", C: P03Primary },
  { slug: "logo-anatomy", C: P04Anatomy },
  { slug: "logo-versions", C: P05Versions },
  { slug: "size-rules", C: P06SizeRules },
  { slug: "clear-space", C: P07ClearSpace },
  { slug: "misuse", C: P08Misuse },
  { slug: "color-dark", C: P09ColorDark },
  { slug: "color-light", C: P10ColorLight },
  { slug: "typography", C: P11Typography },
  { slug: "graphic-motif", C: P12Motif },
  { slug: "iconography", C: P13Icons },
  { slug: "applications-digital", C: P14Digital },
  { slug: "applications-social-events", C: P15Print },
  { slug: "co-branding", C: P16CoBrand },
];

export const BrandGuideCompositions: React.FC = () => (
  <Folder name="BrandGuide">
    {PAGES.map((pg, i) => (
      <Still
        key={pg.slug}
        id={`BG-${String(i + 1).padStart(2, "0")}-${pg.slug}`}
        component={pg.C}
        width={video.width}
        height={video.height}
      />
    ))}
    {[16, 32, 180, 512].map((s) => (
      <Still
        key={s}
        id={`BA-favicon-${s}`}
        component={FaviconAsset}
        defaultProps={{ size: s }}
        width={s}
        height={s}
      />
    ))}
    <Still id="BA-og-banner" component={OgAsset} width={1200} height={630} />
    <Still id="BA-avatar" component={AvatarAsset} width={800} height={800} />
  </Folder>
);
