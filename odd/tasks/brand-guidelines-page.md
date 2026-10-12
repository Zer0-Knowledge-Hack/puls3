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

## Acceptance criteria
- `/brand` renders all sections; every variant has working PNG and SVG links; Download all serves the ZIP.
- Footer shows a Brand link on every screen that uses `SiteFooter`.
- `flutter analyze` and `flutter test` pass.

## Progress / evidence
- Branch `feat/brand-guidelines-page` created from `main` (9438435).
- T1 `bc07263` feat(brand): build the downloadable brand kit. `npm run brand:kit` (design/logo-lab/scripts/build-brand-kit.mjs) rasterizes with Remotion's bundled Chrome headless shell (transparent PNG); no resvg/sharp needed. Output: 61 files + `puls3-brand-kit.zip` (5074 KB), web/brand ~12 MB total. 16 variants (8 lockups, 8 marks), 32 PNGs. ZIP is byte-identical across runs (fixed timestamps, sorted entries). Doto included with OFL.txt.
- T2+T3 `6e03af1` feat(app): add the /brand guidelines page. Dart mirror `lib/src/brand/brand_kit.dart` tested against `web/brand/manifest.json` and `tokens.json`; previews load PNGs via `Image.network` (relative `brand/...` URLs, resolved against `<base href>`). Test-first: RED observed (missing files / no Brand link), then GREEN. ~1070 authored lines (over the 400 advisory heuristic: screen + 2 molecules + kit mirror + 3 test files).
- Checks: `flutter analyze` no issues; `flutter test` 212 passed, 0 failed.

## Next step
T4: run locally (`flutter run -d web-server` or `flutter run -d chrome`) and open `/brand` (hash routing: `/#/brand`).
