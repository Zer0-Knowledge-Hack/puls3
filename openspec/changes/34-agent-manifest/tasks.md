# Tasks: AgentManifest domain model and validation (#34)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,100 authored (incl. tests): 200 + 400 + 380 + 120 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 values -> PR 2 draft/validate -> PR 3 JSON/canonical -> PR 4 docs |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

Notes:
- Stacked-to-main: PR n targets PR n-1's branch until it merges, then main. Each PR carries a dependency diagram marking itself with the pin marker. Every PR stays <= ~400 authored lines.
- Contingency (no size exception): if PR 2 passes ~400, split at 2.8 into PR 2a (draft + `_check`) and PR 2b (`AgentManifest` + `validate` + `toDraft`). If PR 3 passes ~400, split at 3.9 into PR 3a (JSON) and PR 3b (canonical + examples + CI).
- Deviation from the request: the `workers-ai` example and the CI path filter ship in PR 3 (design slice 3), because the fixture tests (S38-S40) need both. PR 4 is docs only.
- Strict TDD: each GREEN task is preceded by its RED task. Test file: `puls3_domain/test/manifest_test.dart`, one `group` per invariant (I23-I32).
- Gate for every PR (run in `puls3_domain`): `dart analyze --fatal-infos && dart test`, plus `dart format --set-exit-if-changed .`.
- Commits: conventional, no Co-Authored-By or AI attribution. Tests stay in the commit of the behavior they verify.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Errors, `ModelId`, `ModelPolicy`, `ManifestVersion`, spec reconcile, `openspec/config.yaml` | PR 1 `feat/34-agent-manifest-01-values` (base main) | `cd puls3_domain && dart test test/manifest_test.dart` | N/A: pure-Dart value objects, no runtime boundary | Revert PR 1 (new file + additive errors/export) |
| 2 | `AgentManifestDraft`, `AgentManifest`, `_check`, `validate` | PR 2 `feat/34-agent-manifest-02-validate` (base PR 1) | same | N/A: pure domain logic | Revert PR 2; PR 1 stays valid |
| 3 | `fromJson`/`toJson`, canonical form, example fixtures, CI filter | PR 3 `feat/34-agent-manifest-03-json` (base PR 2) | same | `dart test` reading `../docs/architecture/examples/*.json` | Revert PR 3; draft/validate stay usable |
| 4 | ADR-0004 amendment, model.md, api.md | PR 4 `docs/34-agent-manifest-04-docs` (base PR 3) | `rg "I23\|ManifestVersion" docs/domain/model.md` | N/A: docs only | Revert PR 4 |

## PR 1: Values and errors (~200 lines)

- [x] 1.1 Reconcile `specs/agent-manifest/spec.md`: add scenarios S41 (ModelId: provider kebab <=32, id non-blank, no whitespace, <=128 runes), S42 (`ModelPolicy` throws `ArgumentError` if `paidProviders` contains `workers-ai`), S43 (`inputMaxChars`/`outputMaxChars` < 1 -> `...TooLow`, restating S20/S21). Resolves design open question on 32/128 caps. Done: spec lists S1-S43.
- [x] 1.2 Add `openspec/config.yaml` and the `openspec/changes/34-agent-manifest/` artifacts to the PR 1 commit. Done: files tracked.
- [x] 1.3 RED: `manifest_test.dart` skeleton + group I25 `ManifestVersion`: 0/-1 rejected with `InvalidManifest`, 1 ok, `first`, `next()`, ordering (S27, S28, S29 next part). Files: `puls3_domain/test/manifest_test.dart`. Done: fails (symbols missing).
- [x] 1.4 GREEN: `ManifestProblem` enum (full list from design Problems table) and `InvalidManifest(List<ManifestProblem>)` (`DomainError`, non-empty, readable message) in `puls3_domain/lib/src/errors.dart`; create `lib/src/manifest.dart` with `ManifestVersion`; export in `lib/puls3_domain.dart`. Done: 1.3 green (S25 list shape, S27-S29).
- [x] 1.5 RED: group I23 `ModelId` (S41): shape, kebab provider, 32/33, id 128/129 runes, blank/whitespace id, no credential field (S19 type-level), equality. Done: fails.
- [x] 1.6 GREEN: `ModelId` factory throwing `InvalidManifest([modelMalformed])` (D12). Done: 1.5 green.
- [x] 1.7 RED: group I24 `ModelPolicy` (S15-S18, S42): `allows` hit/miss for `workers-ai`, paid enabled/disabled/unknown, `isPaid`, `ArgumentError` for `workers-ai` in paid set. Done: fails.
- [x] 1.8 GREEN: `ModelPolicy` with `freeProvider`, `allows`, `isPaid`, unmodifiable sets. Done: 1.7 green.
- [x] 1.9 REFACTOR: tidy, `dart format`, run gate; commit `feat(domain): add manifest values, model policy and problems`. Done: gate green, diff <=~400.

## PR 2: Draft and validate (split into 2a and 2b)

Split at 2.8 (auto-chain, no size exception): PR 2 reached ~720 lines.
- PR 2a `feat/34-agent-manifest-02a-draft` (base PR 1): 2.1-2.5.
- PR 2b `feat/34-agent-manifest-02b-validate` (base 2a): 2.6-2.8.

PR 1 review follow-ups (moved to PR 1, commit `cfe0dc2` `fix(domain): cap manifest version and word manifest problems readably` on `feat/34-agent-manifest-01-values`):

- [x] R.1 REL-001: `ManifestVersion` capped at 2^53-1 (`maxValue`); `next()` at the cap throws `InvalidManifest([versionInvalid])`. Tests: cap, cap+1, `next()` at and below the cap.
- [x] R.2 REL-002: `InvalidManifest.message` maps each `ManifestProblem` through a `switch` to readable text; test updated (no raw enum names) and a test checks every problem has a unique readable text.

Notes: `problemsForDeploy` landed in 2a (2.3) and is tested there (one line over `_check`). Skill per-index problems (`skillIdNotKebabCase`, `skillNameLength`, S14) cannot occur on a `Skill` list because `Skill` validates on construction; they surface from JSON in PR 3 (3.2). S25 six-at-once uses `inputMaxChars: 0` (a value above the max is rejected when the draft is built, per S3).

- [x] 2.1 RED: group I27 Text rules via draft/`validate` helpers: runes (3 emoji pass), whitespace-only = missing, no trimming, boundaries 3/48, 10/280, 20/8000 (S8-S11). Done: fails.
- [x] 2.2 RED: group I26 Draft tolerance: empty draft ok (S1), below-min ok (S2), above-max rejected for name/prompt/maxChars (S3). Done: fails.
- [x] 2.3 GREEN: `AgentManifestDraft` factory + private `_check(fields, {forDeploy, policy})` (ordered, deduplicated problems; text and max rules; D2, D3, D10). Done: 2.1 draft-mode parts and 2.2 green.
- [x] 2.4 RED: group I28-I31 field rules: skills count 0/1/5/6, duplicate id, invalid id/name per index, `Skill` reused (S12-S14); input/output boundaries and types (S20, S21); price positive, asset (S22 non-float part, S23); model policy problems (S15-S17, S43). Done: fails.
- [x] 2.5 GREEN: extend `_check` with skills, model, input, output and price rules; `problemsForDeploy(policy)`. Done: 2.4 green.
- [x] 2.6 RED: group I32 Deploy: complete draft -> `AgentManifest` v1 (S5), all-missing list (S6), six problems at once in fixed order (S25), same input twice equal (S26), immutability of skills and tags (S7), `toDraft()` has no version and original unchanged (S29). Done: fails.
- [x] 2.7 GREEN: `AgentManifest` (non-null, unmodifiable lists, value equality) + `validate(policy, version)` + `toDraft()`. Done: 2.6 green.
- [x] 2.8 REFACTOR: dedupe field checks, gate, commit `feat(domain): add agent manifest draft and deploy validation`. Check line count; apply the split contingency here if >~400.

## PR 3: JSON, canonical form, examples (~380 lines)

- [x] 3.1 RED: group Draft/JSON: wrong types (S4), `tools` -> `toolsNotSupported` distinct from `unknownKey` (S24), `version` in draft -> `versionInDraft`, unknown key at top/`skills[0]`/`input`/`price`/`model` (S19, S32), non-object -> `notAnObject`. Done: fails.
- [x] 3.2 GREEN: `AgentManifestDraft.fromJson(Object?)` and `toJson()` (snake_case mapping, nulls omitted, no throw on type errors; parse problems merged with `_check`; D7, D8, D11). Done: 3.1 green.
- [x] 3.3 RED: round trips and manifest JSON: draft round trip with partial fields (S31), manifest round trip (S30), wrong `schema` (S33), missing/invalid `version` -> `versionInvalid`, `schema` always emitted. Done: fails.
- [x] 3.4 GREEN: `AgentManifest.fromJson(json, policy)` and `toJson()`. Done: 3.3 green.
- [ ] 3.5 RED: group Canonical: no whitespace, sorted keys at every depth (S34), key-order independence (S35), UTF-8 non-ASCII (S36), one-field edit changes bytes (S37), any double throws `StateError`. Done: fails.
- [ ] 3.6 GREEN: `toCanonicalJson()` via `_sortKeysDeep` + `jsonEncode`; `dart:convert` only. Done: 3.5 green.
- [ ] 3.7 Create `docs/architecture/examples/agent-manifest.workers-ai.example.json` (`workers-ai`, `@cf/meta/llama-3.1-8b-instruct`, version 1). Done: file valid JSON, no credential key.
- [ ] 3.8 RED then GREEN: fixture tests read `../docs/architecture/examples/*.json`: Copy Forge validates with `anthropic` enabled (S38), workers-ai validates and `isPaid` false (S39), restrictive policy yields exactly one model problem each (S40), `toJson` equals source doc. Adjust `agent-manifest.example.json` only if needed. Done: green.
- [ ] 3.9 Edit `.github/workflows/ci.yml` path filter: `docs/architecture/examples/*` -> `domain=true`. REFACTOR, gate, commit `feat(domain): add manifest JSON, canonical form and example fixtures`. Check line count; split contingency here.

## PR 4: Docs (~120 lines, docs only)

- [ ] 4.1 Amend `docs/adr/0004-*.md`: one `{provider,id}` model per agent (free `workers-ai` or BYOK), injected `ModelPolicy`, credential ref in the deploy record with `isPaid` -> stored-credential check, model change = new version, hash/salt move to #18 (supersedes line 32), drafts have no version.
- [ ] 4.2 Update `docs/domain/model.md`: glossary (Manifest, Draft, ModelId, ModelPolicy, ManifestVersion), diagram node, invariants I23-I32 matching test groups.
- [ ] 4.3 Update `docs/architecture/api.md:277`: remove `version` from `AgentManifestDraft`; add the wire mapping note (D7); keep `DraftVersionConflict` as storage concern.
- [ ] 4.4 Verify links and invariant ids against tests; commit `docs: document agent manifest model and amend ADR-0004`. Done: `rg "I2[3-9]|I3[0-2]" docs/domain/model.md` shows I23-I32.

## Risks

- PR 2 and PR 3 are at the budget edge; contingency splits are predefined and need no exception.
- Docs lag code until PR 4 merges; PR 3 CI filter keeps fixture tests re-running when examples change.
- Spec edit (1.1) introduces S41-S43; verify must check them.
- `Skill` still counts UTF-16 length (left as is because of PR #120).
