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

## Remaining

PR 4 (4.1-4.4).
