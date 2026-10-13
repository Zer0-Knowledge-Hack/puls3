# Tasks: Agent Catalog Index

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~700 hand-written + generated models/migration |
| 400-line budget risk | High |
| Chained PRs recommended | Yes (ledger, then index, then wiring) |
| Suggested split | 1) RPC events + parser, 2) models + repository + indexer, 3) endpoint/wiring |
| Delivery strategy | ask-on-risk |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception (user accepted a single branch for the issue)

## Work Units

| Unit | Goal | Focused test command | Rollback boundary |
|------|------|----------------------|-------------------|
| 0 | Record live RPC fixtures | `dart test test/unit/ledger` | Delete new fixtures |
| 1 | `getLatestLedger`, `getEvents` | `dart test test/unit/ledger` | Revert `soroban_rpc_client.dart` |
| 2 | `registry_events.dart` | `dart test test/unit/ledger` | Revert parser + reader |
| 3 | Models + migration + repository | `dart test test/integration` | Revert `.spy.yaml`, generated, migration |
| 4 | `CatalogIndexer` | `dart test test/unit/agent` | Revert indexer + summary reader |
| 5 | Indexed service, endpoint, wiring | `dart test` | Revert agent endpoint/wiring/`server.dart` |

## Unit 0: Fixtures

- [x] 0.1 Record `getLatestLedger` and a registry `getEvents` page from
  soroban-testnet into `test/unit/ledger/fixtures/`.

## Unit 1: RPC events

- [x] 1.1 `soroban_rpc_client.dart`: `RpcEvent`, `EventPage`,
  `RpcEventFilter`, `getLatestLedger`, `getEvents` (ledger range xor cursor).
- [x] 1.2 Tests: params, parsing, cursor-only, `ArgumentError`, malformed.

## Unit 2: Registry event parser

- [x] 2.1 `registry_events.dart`: `registered`, `metadata_set`, `uri_updated`.
- [x] 2.2 `RegistryEventReader` port and `SorobanRegistryEventReader`
  (cursor pagination, contract filter).
- [x] 2.3 Tests: each event, skips (other contract, failed, unknown, malformed),
  the recorded agent 7 registration.

## Unit 3: Models and repository

- [x] 3.1 `agent_record.spy.yaml`, `catalog_index_state.spy.yaml`.
- [x] 3.2 `AgentIndexRepository` port, `ServerpodAgentIndexRepository`.
- [x] 3.3 `serverpod generate` + migration; commit generated output.
- [x] 3.4 Integration tests: idempotent upsert, update, newest per id, cursor.

## Unit 4: Indexer

- [x] 4.1 Extract `readAgentSummary` shared by the catalog and the indexer.
- [x] 4.2 `CatalogIndexer` with `IndexPassSummary`.
- [x] 4.3 Tests: bootstrap, incremental, missing-agent recovery, twice =
  no duplicates, invalid skipped, outage, retention gap.

## Unit 5: Endpoint and wiring

- [x] 5.1 `CatalogReader` port; `AgentCatalogService implements CatalogReader`.
- [x] 5.2 `IndexedAgentCatalogService` (index first, chain fallback).
- [x] 5.3 `agent_catalog_wiring.dart`; `AgentEndpoint` depends on
  `CatalogReader` only.
- [x] 5.4 `CatalogIndexerLoopConfig` + `startCatalogIndexer`; register in
  `server.dart`.
- [x] 5.5 `.env.example` and README.
- [x] 5.6 Tests: indexed service, endpoint delegation, endpoint index
  integration (chain down still serves the index).

## Unit 6: Gates

- [x] 6.1 `dart analyze --fatal-infos` clean.
- [x] 6.2 `dart test` green (unit + integration).
- [x] 6.3 `serverpod generate` leaves no diff.
