# Exploration: fix-flutter-onchain-catalog

Full analysis: engram `sdd/fix-flutter-onchain-catalog/explore`.

## Current state

- `puls3_flutter/lib/main.dart` builds `Client(apiUrl)` (only used for the health check) and runs `Puls3App(repository: AssetAgentRepository(), wallet: MockWallet(), ...)`.
- `AgentRepository.fetchAgents()` is the single seam for the catalog. `AgentCatalog.load()` merges fetched agents with anything published in the session; on error it stores `_error` and leaves the list empty (no UI reads it).
- `Agent` requires `id, name, description, skills (display strings), priceUsdcStroops, rating, stellarAddress, model`. The generated client exposes `client.agent.list()` returning `AgentSummary { id, registryId, name, description, skills (kebab ids), priceUsdcStroops, wallet?, model? }` and throws `AgentCatalogUnavailable`.
- Consumers: `rating` in `RatingBadge` (card and detail); `stellarAddress` as the hire destination in `hire_sheet.dart` and in `shortenAddress`/`AddressBadge`; Studio and deploy sheet build `Agent` directly with rating 5.0.
- Skill ids are the display strings lowercased with hyphens, except `on-chain-analytics` (display "On-chain analytics"). 17 distinct skill ids exist across the 8 demo agents.

## Approaches

| Approach | Verdict |
|---|---|
| A. `ServerAgentRepository` + `FallbackAgentRepository` composed in `main.dart` | Recommended: one seam, no screen or catalog changes, offline demo kept |
| B. Make `AgentCatalog` aware of two repositories | More scope and state changes |
| C. Server only | Breaks the offline demo |

## Defaults chosen

- Explicit const skill table (17 ids) plus a generic fallback (hyphens to spaces, first letter uppercase) in a pure function `skillDisplayName`.
- No on-chain rating: `rating` is 0.0 and `RatingBadge` renders nothing when `rating <= 0`.
- Agents without a wallet are dropped by the mapper (an agent that cannot be paid cannot be hired); `stellarAddress` is the wallet.
- `model` defaults to `Unspecified`.
- Fall back to the asset catalog on any thrown error, never on an empty successful list.
- `ServerAgentRepository` takes an injectable source function (`() => client.agent.list()`) so tests do not fake the generated client.
- A bounded call timeout so a hanging server does not block the market (confirm the Serverpod client option names before using them).

## Risks

- Fake ratings would mislead; the UI must tolerate a missing badge in the card and detail layouts.
- A silent fallback can mask outages; the existing backend banner only reflects the health call.
- `flutter test` has not been run yet in this workspace.

## Budget

About 150-200 lines including tests; single PR.
