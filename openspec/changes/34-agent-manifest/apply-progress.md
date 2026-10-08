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

## PR 2a (feat/34-agent-manifest-02a-draft): DONE, R.1, R.2, 2.1-2.5

PR 2 was split at 2.8 (auto-chain). 2a is based on PR 1.
- R.1 REL-001: `ManifestVersion.maxValue` = 2^53-1; the factory and `next()` fail with `InvalidManifest([versionInvalid])` past it.
- R.2 REL-002: `InvalidManifest.message` is a `switch` over `ManifestProblem`; the enum-name test was replaced.
- 2.1-2.3 `AgentManifestDraft`, `InputType`, `OutputType`, private `_check` (ordered; runes, whitespace = missing, no trim; a draft skips only missing and below-min), `problemsForDeploy`.
- 2.4/2.5 skills (count, duplicate id), model policy problems, input/output max chars, price positivity.

Deviations: S14 per-skill problems and wrong-type problems are unreachable with typed Dart fields; they land with JSON in PR 3.

TDD evidence: each group was written first and run to failure before the implementation.

## Remaining

PR 2b (2.6-2.8), PR 3 (3.1-3.9), PR 4 (4.1-4.4).
