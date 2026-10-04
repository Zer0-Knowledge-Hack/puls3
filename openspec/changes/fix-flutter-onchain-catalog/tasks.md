# Tasks: Flutter On-chain Catalog

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 450-650 (about 150 production, rest tests) |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | Single PR, commit-sized work units 0-6 |
| Delivery strategy | ask-on-risk |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

The user already accepted a single PR with `size:exception` for this stream. Each unit is one commit.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 0 | Record baseline | PR 1 | `flutter test` | N/A: no code change | None |
| 1 | `skillDisplayName` | PR 1 | `flutter test test/domain/skill_display_name_test.dart` | N/A: pure function | New domain file and test |
| 2 | `ServerAgentRepository` | PR 1 | `flutter test test/data/server_agent_repository_test.dart` | N/A: fake source | New data file and tests |
| 3 | `FallbackAgentRepository` | PR 1 | `flutter test test/data/fallback_agent_repository_test.dart` | N/A: counting fakes | New data file and test |
| 4 | `RatingBadge` hides when unrated | PR 1 | `flutter test test/ui test/screens` | Widget tests at phone and desktop sizes | Badge file and its tests |
| 5 | Composition and app tests | PR 1 | `flutter test test/app` | Widget tests via `pumpApp(repository:)` | `main.dart` and `helpers.dart` |
| 6 | Gates and docs | PR 1 | `flutter analyze --fatal-infos && flutter test` | Full suite | Docs only |

All commands run in `puls3_flutter`. After any pub command, run `git restore pubspec.lock` at the repo root (local Dart 3.10, lock needs 3.11). Timeout tests use plain `test` (real timers).

## Phase 0: Baseline (unit 0)

- [ ] 0.1 Run `flutter analyze --fatal-infos` and `flutter test` in `puls3_flutter` before changes; record results in the commit message or notes. Run `git restore pubspec.lock` afterwards.

## Phase 1: Skill names (unit 1, spec: Skill display names)

- [ ] 1.1 RED: `puls3_flutter/test/domain/skill_display_name_test.dart` covers the 17 ids, `yield-farming` -> `Yield farming`, `quant` -> `Quant`, `''` -> `''`.
- [ ] 1.2 GREEN: create `puls3_flutter/lib/src/domain/skill_display_name.dart` (const table plus generic fallback, no Flutter import).

## Phase 2: Server repository (unit 2, spec: Server-backed repository, Mapping, Wallet, Timeout)

- [ ] 2.1 RED: `puls3_flutter/test/data/server_agent_repository_test.dart`: single call and order, error propagates, null and empty wallet dropped, all dropped -> `[]`, null and empty model -> `Unspecified`, full mapping (rating 0.0, stellarAddress = wallet).
- [ ] 2.2 RED: same file, plain `test`: never-completing `Completer` with `timeout: Duration(milliseconds: 10)` throws `TimeoutException`; fast source unaffected.
- [ ] 2.3 GREEN: create `puls3_flutter/lib/src/data/server_agent_repository.dart` (`AgentSummarySource`, `defaultTimeout` 20 s, `fromSummary`, unmodifiable lists).
- [ ] 2.4 REFACTOR: tidy and re-run analyze.

## Phase 3: Fallback repository (unit 3, spec: Fallback repository)

- [ ] 3.1 RED: `puls3_flutter/test/data/fallback_agent_repository_test.dart`: success skips fallback, empty skips fallback, throw / `AgentCatalogUnavailable` / `TimeoutException` -> fallback.
- [ ] 3.2 GREEN: create `puls3_flutter/lib/src/data/fallback_agent_repository.dart` (catch all, `debugPrint`).

## Phase 4: Rating badge (unit 4, spec: agent-rating-display)

- [ ] 4.1 RED: `puls3_flutter/test/ui/rating_badge_test.dart`: 0.0 and -1.0 render no `Text`/`Icon`; 4.5 -> `4.5`; 5.0 -> `5.0`.
- [ ] 4.2 RED: card (pumped directly) and detail (`pumpApp(repository:)`) with rating 0.0 at phone and desktop sizes: no exception, no rating text; rated 5.0 unchanged.
- [ ] 4.3 GREEN: `puls3_flutter/lib/src/ui/atoms/rating_badge.dart` returns `SizedBox.shrink()` when `rating <= 0`.

## Phase 5: Composition (unit 5, spec: App composition)

- [ ] 5.1 Modify `puls3_flutter/test/helpers.dart`: `pumpApp` gains optional `AgentRepository repository` (default `InMemoryAgentRepository(testAgents)`).
- [ ] 5.2 RED: app tests: server source shows `On-chain analytics`; throwing primary shows `testAgents`; empty primary shows empty market.
- [ ] 5.3 GREEN: compose `FallbackAgentRepository(ServerAgentRepository(() => client.agent.list()), AssetAgentRepository())` in `puls3_flutter/lib/main.dart`.

## Phase 6: Gates and docs (unit 6)

- [ ] 6.1 Run `flutter analyze --fatal-infos` and `flutter test`; then `git restore pubspec.lock` at the repo root.
- [ ] 6.2 Check `puls3_flutter/README.md`: it does not mention the catalog today; add a short note on the server catalog and asset fallback only if a fitting section exists.

## Decisions

- Detail `Wrap` gap with no badge is cosmetic (one `Puls3Spacing.sm` gap). Leave `agent_detail_screen.dart` unchanged unless the 4.2 test shows breakage.
- The 20 s timeout is a constructor parameter; keep the default (non-blocking).
