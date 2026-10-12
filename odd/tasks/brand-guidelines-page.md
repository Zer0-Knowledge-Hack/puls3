# Brand guidelines page

## Objective
Publish the existing puls3 brand guide as a `/brand` page in the Flutter web app, linked from the footer, with PNG and SVG downloads per asset and a "Download all" bundle at the top. Reference: https://www.bnbchain.org/en/brand-guidelines

## Problem / why
Brand assets live in `assets/brand/`, `docs/brand/` and `design/logo-lab/`, but nothing in the product exposes them. Partners and press have no public place to get the official logo.

## Scope
- PNG exports for every logo and mark variant (only SVG exists today).
- A deterministic ZIP bundle (`puls3-brand-kit.zip`) with all SVG + PNG + guide PDF.
- Static download files served from `puls3_flutter/web/brand/` (plain links, not the Flutter asset bundle).
- `/brand` route: hero + Download all, logo variants grid (PNG/SVG each), colors (HEX/RGB from `docs/brand/tokens.json`), typography, size and clear-space rules, do/don't, co-branding ("Built on Stellar").
- Footer link "Brand" in `SiteFooter`.

## Constraints
- Local only: no push, no deploy. User tests locally first.
- Delivery strategy: ask-on-risk. Forecast ~500–700 authored lines (excluding generated binaries).
- English UI copy. Follow existing atomic design (`ui/atoms|molecules|organisms`, `screens/`).

## Tasks
- [x] T1 — Asset pipeline: PNG exports + ZIP bundle script, output copied to `puls3_flutter/web/brand/`. Route: delegated. Commit `bc07263`.
- [x] T2 — `/brand` screen + route + widget tests. Route: delegated (2+ non-trivial files). Commit `6e03af1`.
- [x] T3 — Footer link + test. Route: delegated with T2. Commit `6e03af1`.
- [ ] T4 — Run locally (`flutter run -d web-server`) for the user to test.

### Redesign round (user feedback after local test, BNB comparison)
Rationale: our page explains with text; BNB shows each rule visually, curates fewer choices and reveals actions on hover.
- [x] T5 — Hero: centered mark with dashed construction guides, title below; hide "Backend unavailable" banner on `/brand`. Route: delegated. Commit `544af84`.
- [x] T6 — Logos: curate to 8 cards (dark, light, mono-white, mono-ink × lockup, mark); hover/tap overlay with PNG, SVG, Copy SVG; "Download all" in the Logos section header; small sizes stay ZIP-only. Route: delegated. Commits `544af84`, `5a7ae2d`. Deviation: 6 cards, the kit has no mono-white/mono-ink mark files (needs `design/logo-lab/scripts/build-brand-kit.mjs`).
- [x] T7 — Colors: 4 primary swatches large with copy-to-clipboard per value (HEX, RGB, approximate CMYK labelled as such; no Pantone); secondary palette collapsible. Route: delegated. Commit `9952b0a`.
- [x] T8 — Guidelines: numbered Dimensions rows (min-size ✓ vs below-min ✗ with ruler) + Safe space diagram (4c). Route: delegated. Commit `9952b0a`.
- [x] T9 — Usage Do's / Don'ts as rendered visual cards (green/red bottom border): recolor, outline, shadow, gradient, stretch, busy background, low contrast, halftone 3 at small size. Route: delegated. Commit `23b76c3` (halftone-at-small-size lives in Dimensions row 04).
- [x] T10 — New "Using puls3 in your project" section (can do / should avoid / expectations), DRAFT copy adapted from BNB — requires user/brand-owner approval before publish. Route: delegated. Commit `23b76c3`; copy in `puls3_flutter/lib/src/brand/brand_policy.dart` (DRAFT header, `contactEmail` TODO = null, no email link rendered). Approval still pending.
- [x] T11 — Mono-white and mono-ink C01 marks (user-authorized): export from `design/logo-lab/scripts/export-brand.tsx`, add to the kit in `build-brand-kit.mjs`, show 8 curated cards. Route: delegated. Commit `b160bb9`.
- Out of scope: vertical lockup (needs design in logo-lab), official Pantone.

## Acceptance criteria
- `/brand` renders all sections; every variant has working PNG and SVG links; Download all serves the ZIP.
- Footer shows a Brand link on every screen that uses `SiteFooter`.
- `flutter analyze` and `flutter test` pass.

## Progress / evidence
- Branch `feat/brand-guidelines-page` created from `main` (9438435).
- T1 `bc07263` feat(brand): build the downloadable brand kit. `npm run brand:kit` (design/logo-lab/scripts/build-brand-kit.mjs) rasterizes with Remotion's bundled Chrome headless shell (transparent PNG); no resvg/sharp needed. Output: 61 files + `puls3-brand-kit.zip` (5074 KB), web/brand ~12 MB total. 16 variants (8 lockups, 8 marks), 32 PNGs. ZIP is byte-identical across runs (fixed timestamps, sorted entries). Doto included with OFL.txt.
- T2+T3 `6e03af1` feat(app): add the /brand guidelines page. Dart mirror `lib/src/brand/brand_kit.dart` tested against `web/brand/manifest.json` and `tokens.json`; previews load PNGs via `Image.network` (relative `brand/...` URLs, resolved against `<base href>`). Test-first: RED observed (missing files / no Brand link), then GREEN. ~1070 authored lines (over the 400 advisory heuristic: screen + 2 molecules + kit mirror + 3 test files).
- Checks: `flutter analyze` no issues; `flutter test` 212 passed, 0 failed.

- T4: served locally with `flutter run -d web-server --web-port 8787`; `/` and `/brand/puls3-brand-kit.zip` return 200 (zip 5,195,962 bytes). Parent spot check: 13 brand/footer tests pass.
- Review: RDD on; assess (untracked excluded) = medium, `slice_budget_reached` (74 paths, 2113 lines incl. generated). Native review deferred until the user finishes local testing, so feedback fixes land in the same candidate.

- Redesign round (T5–T10), test-first per commit (RED observed: missing symbols, banner visible on `/brand`; then GREEN):
  - `544af84` feat(brand): hero with construction guides and curated logo cards. Banner hidden via `routeInformationProvider` (listening to `routerDelegate` threw setState-during-build).
  - `5a7ae2d` fix(brand): preview logo cards from the largest PNG. The full-size kit SVGs nest the mark in an inner `<svg>`, which flutter_svg does not draw; Copy SVG still copies the original markup (bundled as Flutter assets from `web/brand/svg/{logo,mark}/`).
  - `9952b0a` feat(brand): primary colors and visual dimension rules. CMYK is a naive RGB conversion labelled "CMYK (approx.)".
  - `23b76c3` feat(brand): visual usage rules and third-party usage policy.
  - Numbers verified: README 07 (c = 0.072 × mark height, 4c clear space, minimums lockup mark 24 / mark 16 / wordmark 14 px) and README 06 (halftone 3 at lockup mark ≥ 72 px, C01 full ≥ 48 px) agree with `Puls3LogoTokens` and logo.tsx (`THREE_HALFTONE_MIN_PX = 40`, `MARK_FULL_MIN_PX = 48`, 72 derived); C01 center dot r = 4.60 of 128 in the SVG = 0.0719. No discrepancies. Digital minimums 16/14 exist only in the README (not in logo.tsx).
  - Wordmark sample is cropped from the small lockup SVG (box from logo.tsx `WM`: ascender to descender ± 30 units), never retyped.
  - "Don't" red `#F2555A` is a page-local constant (tokens.json has no error color) — flag for brand review.
  - Checks: `flutter analyze` no issues; `flutter test` 234 passed, 0 failed (incl. 360 px phone and 800 px tablet no-overflow tests).
  - ~2300 authored lines added across 4 commits (over the 400 advisory heuristic: 6 new organisms/molecules with painters and tests).
  - `6519cc6` fix(app): handle a failed health check when the banner is hidden. A release build logged `Uncaught` on `/#/brand` only: with the banner hidden, nothing listened to the failing health-check future. A regression test (Completer failing after startup, on `/brand`) failed before the fix and passes after it. Re-verified with the release build on :8788 using headless Chrome over CDP: no exceptions on `/#/brand` or `/#/`. `flutter analyze` clean; `flutter test` 234 passed.
  - `b160bb9` feat(brand): add mono-white and mono-ink marks (T11). `npm run brand:export` writes the two new marks (nested `<svg>` like the existing full marks, one fill each: #F6F7F8 / #0B0B0D). It also rewrites the other 18 SVGs and tokens.json with LF line endings, but with `core.autocrlf=true` git sees no content diff, so those were restored, not committed. `npm run brand:kit`: 61 to 67 files (+2 SVG, +4 PNG), zip 5,195,962 to 5,453,124 bytes; a second run gave the same zip SHA-256 (02769f1b…). Test-first: the 8-card and curated-ids tests failed, then passed. `flutter analyze` clean; `flutter test` 234 passed. Release build on :8788: headless screenshot shows the 8 cards, and no Uncaught in the console.

## Next step
Local only: no PR and no deploy until the user says otherwise (2026-10-12). Pending user decisions: approve T10 copy + contact email, the ✗ red #F2555A, and a 4-column logo grid (8 cards = 2 rows). Then run the native review preflight (`--untracked-scope=exclude`). To test: `flutter build web --release` and serve `puls3_flutter/build/web`.
