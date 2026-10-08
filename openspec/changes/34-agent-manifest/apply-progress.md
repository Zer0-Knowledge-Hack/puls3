# Apply progress: 34-agent-manifest

## PR 1 (feat/34-agent-manifest-01-values): DONE, tasks 1.1-1.9

- 1.1 Spec reconciled: S41 (ModelId shape), S42 (workers-ai not paid), S43 (max chars below one); requirement text updated.
- 1.2 `openspec/config.yaml` and change artifacts committed.
- 1.3/1.4 `ManifestVersion`, `ManifestProblem`, `InvalidManifest` (non-empty, unmodifiable, readable message).
- 1.5/1.6 `ModelId` (provider kebab <=32, id non-blank, no whitespace, <=128 runes).
- 1.7/1.8 `ModelPolicy` (`freeProvider`, `allows`, `isPaid`, unmodifiable copies, `ArgumentError` for workers-ai in paid set).
- 1.9 Gate: `dart analyze --fatal-infos` clean, `dart test` 149 passed, `dart format --set-exit-if-changed` clean.

## TDD evidence

Each group was written first and run to failure (symbols missing) before the implementation.

## PR 1 review follow-ups: DONE, R.1, R.2 (moved to PR 1, commit cfe0dc2 on feat/34-agent-manifest-01-values)

PR 2 was split at 2.8 (auto-chain). 2a is based on PR 1.
- R.1 REL-001: `ManifestVersion.maxValue` = 2^53-1; the factory and `next()` fail with `InvalidManifest([versionInvalid])` past it.
- R.2 REL-002: `InvalidManifest.message` is a `switch` over `ManifestProblem`; the enum-name test was replaced.

## PR 2a (feat/34-agent-manifest-02a-draft): DONE, 2.1-2.5

PR 2 was split at 2.8 (auto-chain). 2a is based on PR 1.
- 2.1-2.3 `AgentManifestDraft`, `InputType`, `OutputType`, private `_check`, `problemsForDeploy`.
- 2.4/2.5 skills (count, duplicate id), model policy problems, input/output max chars, price positivity.

Deviations: S14 per-skill problems and wrong-type problems are unreachable with typed Dart fields; they land with JSON in PR 3.

## PR 2b (feat/34-agent-manifest-02b-validate): DONE, 2.6-2.8

- 2.6/2.7 `AgentManifest` (value equality, unmodifiable skills/tags), `validate(policy, version)`, `toDraft()`.
- 2.8 Gate green.
- S25 six-at-once uses `inputMaxChars: 0` (above-max is a build-time error in drafts, S3).

TDD evidence: each group was written first and run to failure before the implementation (the I32 group failed to compile before `AgentManifest` existed).

Test-hardening commit (PR 2b, tests only, `test(domain): harden manifest rune, equality and immutability tests`): REL-001 emoji rune counting for name/description/systemPrompt, REL-002 equality per field and hash stability, REL-003 caller-list aliasing, REL-004 type-without-max, toDraft round trip, whitespace-only prompt. Characterization tests; each was checked by mutating production code (runes.length -> length, dropping each field from `==`/`_sameSkills`, removing the skills copy, unstable hashCode) and every mutation failed the suite before restore.

## PR 3a (feat/34-agent-manifest-03a-json): DONE, 3.1-3.4

PR 3 was split at 3.4/3.5 (the JSON part alone passed ~400 authored lines: 336 code + 361 tests).
- 3.1/3.2 `AgentManifestDraft.fromJson`/`toJson`; private `_parseDocument` turns every type mismatch into a problem; parse problems are merged with `_check` through `_merge` (ordered, deduplicated; a `xMissing` is dropped when the same field is already `xMalformed`/skill-invalid).
- 3.3/3.4 `AgentManifest.fromJson(json, policy)` and `toJson()`; `schema` optional on input, `version` required.
- Carried deviation resolved: S14 per-skill problems (`skillIdNotKebabCase`, `skillNameLength`) and wrong-type problems are now reachable and tested through JSON.
- Deviations: one `unknownKey` per document (deduplicated, no key name or path in the enum); `schema` in a draft is `unknownKey`; `price` without a valid `USDC` asset is `priceAssetUnsupported`; a skill with a missing `id`/`name` reports the skill rule, not malformed; explicit JSON `null` counts as absent.

## PR 3b (feat/34-agent-manifest-03b-canonical): DONE, 3.5-3.9

- 3.5/3.6 `AgentManifest.toCanonicalJson()` over a public `canonicalJson(Object?)` (sorted keys at every depth via `_sortKeysDeep`, `jsonEncode`, `StateError` on any double, `dart:convert` only). `canonicalJson` is public so the double rule is testable and the server (#18) can reuse it.
- 3.7 `docs/architecture/examples/agent-manifest.workers-ai.example.json` (Brief Bot, `workers-ai`, `@cf/meta/llama-3.1-8b-instruct`, v1).
- 3.8 Fixture tests (S38-S40 and `toJson` equals source) read `../docs/architecture/examples/*.json` from `puls3_domain`. Mutation check: adding a `credential` key to the workers-ai example failed the group, then was restored. The Copy Forge example needed no change.
- 3.9 `.github/workflows/ci.yml`: `docs/architecture/examples/*` sets `domain=true` only.
- Deviation: the example file (3.7) existed before the fixture tests ran, so the 3.8 RED was verified by mutation rather than by a missing file.


## Delivery change and PR 3 fixes (single PR `feat/34-agent-manifest-03-json-docs`)

User decision: everything after PR 2b ships as one PR (base `feat/34-agent-manifest-02b-validate`), as separate commits (3a JSON, 3b canonical and examples, fixes, docs, SDD records) with a `size:exception`. The branch is the renamed `feat/34-agent-manifest-03b-canonical`.

Fixes F.1-F.5 (strict TDD: 7 new or changed tests failed first, then the code; see tasks.md):
- F.1 REL-002 integral numbers are integers (`_integer`, `_wireInteger`; `canonicalJson(3.0) == '3'`); non-integral, NaN, infinite and beyond 2^53-1 are rejected. On the web `3.0` and `3` are indistinguishable (documented).
- F.2 REL-001 `_merge` sorts the deduplicated problems by enum (field) order. `unknownKey` now comes before `toolsNotSupported`.
- F.3 REL-003 `canonicalJson` throws `StateError` for non-string keys.
- F.4 REL-004 new group `JSON edge cases` (15 tests). Decision: `tools` at any depth is `toolsNotSupported` (the parser's `object()` checks every object).
- F.5 REL-005 fixtures resolved via `Isolate.resolvePackageUriSync`; `dart test puls3_domain/test/manifest_test.dart` passes from the repo root.
- Known limit: per-skill problems are deduplicated, so "skill index" order only holds between different skill problem kinds, not between two skills with the same problem.

## PR 4 tasks (4.1-4.4): DONE (same PR, commit `docs: document agent manifest model and amend ADR-0004`)

- 4.1 ADR-0004 amendment: one model chosen once (free `workers-ai` or BYOK), credential ref in the deploy record, `ModelPolicy` injected, drafts have no version, canonical JSON in the domain and the salted SHA-256 moved to #18 (explicit deviation from decision 3), integers on the web, design follows bnb-chain/bnbagent-sdk adapted to Stellar with ERC-8004/8183.
- 4.2 `docs/domain/model.md`: glossary (Manifest, Draft, ModelId, ModelPolicy, ManifestVersion), class diagram nodes, invariants I23-I32 (I28-I31 are the four tests of the `I28-I31 Field rules` group: skills, model, input/output, price).
- 4.3 `docs/architecture/api.md`: `version` removed from `AgentManifestDraft`, wire mapping note added, `DraftVersionConflict` kept as a storage concern.
- 4.4 Links and invariant ids checked against the tests.

## Escalation resolution

User decision (binding): integral numbers written with a decimal point (3000000.0) are accepted as integers everywhere, since dart2js cannot tell `3.0` from `3`. Non-integral, NaN, infinity and |x| > 2^53-1 are rejected.
- E.1 `_integer` now range-checks the `int` branch too (RED: `canonicalJson(9007199254740992)` did not throw). Commit d6595f7. Gate: analyze clean, 234 tests, format clean.
- E.2 spec.md amended for W1 (numbers), W2 (S25 uses `inputMaxChars` 0), W3 (one `unknownKey` per document, one problem per distinct skill problem kind, ordered by field then kind). verify-report W1-W3 marked resolved; W4 (size:exception) kept.

## Remaining

Verify (`sdd-verify`), then open the single PR.
