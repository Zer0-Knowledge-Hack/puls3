# Proposal: Flutter On-chain Catalog

## Intent

The Flutter market shows a bundled asset catalog (`AssetAgentRepository`) even though the server now serves registry-backed agents through `client.agent.list()`. Users never see the agents that are actually on-chain. Wire the app to the server catalog while keeping the offline demo working.

## Scope

### In Scope
- `ServerAgentRepository` mapping `AgentSummary` to `Agent`, with an injectable source function and a bounded call timeout.
- `FallbackAgentRepository(primary, fallback)`: falls back on any thrown error, never on an empty successful list.
- Pure `skillDisplayName`: const table of the 17 known skill ids plus a generic fallback (hyphens to spaces, first letter uppercase).
- Mapping defaults: `rating` 0.0, `model` `Unspecified`, `stellarAddress` = wallet; agents without a wallet are dropped.
- `RatingBadge` renders nothing when `rating <= 0`.
- Composition in `main.dart`; unit and widget tests.

### Out of Scope
- Hire/escrow flow, wallet adapter, server changes, reputation/on-chain ratings.

## Capabilities

### New Capabilities
- `flutter-onchain-catalog`: server-backed repository, summary-to-agent mapping, skill display names, fallback behavior, timeout.
- `agent-rating-display`: rating badge hidden when an agent is unrated.

### Modified Capabilities
- None

## Approach

Approach A from exploration: keep `AgentRepository.fetchAgents()` as the single seam. Compose `FallbackAgentRepository(ServerAgentRepository(() => client.agent.list()), AssetAgentRepository())` in `main.dart`. No changes to `AgentCatalog` or screens beyond `RatingBadge`. Confirm Serverpod client timeout option names before use; otherwise apply `Future.timeout`.

## Affected Areas

| Component | Area | Impact |
|-----------|------|--------|
| app | `puls3_flutter/lib/src/data/agent_repository.dart` (or new sibling files) | New repositories + mapper |
| app | `puls3_flutter/lib/main.dart` | Modified composition |
| app | `puls3_flutter/lib/src/ui/atoms/rating_badge.dart` | Hide when unrated |
| app | `puls3_flutter/test/` | New tests |
| domain, server, client, contracts | — | None |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Silent fallback masks server outages | Med | Health banner unchanged; fallback tested explicitly; follow-up for a source indicator |
| Hidden badge breaks card/detail layout | Low | Widget tests for card and detail with rating 0 |
| Wrong timeout API on generated client | Low | Verify option names; `Future.timeout` fallback |
| `flutter test` not yet run in this workspace | Med | Run analyze + test before apply begins |

## Rollback Plan

Revert the single PR. Minimal rollback: restore `AssetAgentRepository()` in `main.dart`; new classes become unused and harmless.

## Dependencies

- Server agent catalog endpoint (`agent-catalog-endpoint`, archived) and generated `puls3_client`.

## Review Workload

About 150-200 changed lines including tests; single PR, within the 400-line budget.

## Success Criteria

- [ ] With the server reachable, the market lists registry agents with readable skill names.
- [ ] With the server failing or timing out, the asset catalog is shown.
- [ ] An empty server list shows an empty market (no fallback).
- [ ] Agents without a wallet are absent; unrated agents show no badge.
- [ ] `flutter analyze --fatal-infos` and `flutter test` pass in `puls3_flutter`.
