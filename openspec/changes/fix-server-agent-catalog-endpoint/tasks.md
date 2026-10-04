# Tasks: Server Agent Catalog Endpoint

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~300 hand-written + ~600-1000 generated |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | Single PR, commit-sized units 0-5 |
| Delivery strategy | ask-on-risk (user accepted single PR with size:exception) |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units (one commit each, one PR)

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 0 | Live read-only fixtures | PR 1 | `dart test test/unit/ledger` | Read-only simulate calls to soroban-testnet | Delete new fixture files |
| 1 | `ScArg.string`, `totalAgents`, `agentMetadata` | PR 1 | `dart test test/unit/ledger` | N/A, MockClient + recorded fixtures | Revert ledger files and tests |
| 2 | Spy models + generate | PR 1 | `dart analyze --fatal-infos` | `serverpod generate` (3.4.13) | Revert spy yaml and generated output |
| 3 | Validation + service | PR 1 | `dart test test/unit/agent` | N/A, fake `RegistryReader` | Revert `lib/src/agent` non-endpoint files |
| 4 | Endpoint wiring + override | PR 1 | `dart test test/unit/agent` | N/A, override with fake service | Revert endpoint, regenerate |
| 5 | Gates + docs | PR 1 | `dart test test/unit` | `serverpod generate` then `git diff --exit-code` | Revert docs |

All commands run in `puls3_server`.

## Unit 0: Live fixtures

- [ ] 0.1 Record via read-only simulate on soroban-testnet (never hand-written) into `puls3_server/test/unit/ledger/fixtures/`: `simulate_total_agents.json`, `simulate_get_metadata_present.json` (agent 7, key `name`), `simulate_get_metadata_void.json` (agent 0, key `name`).

## Unit 1: Ledger additions

- [ ] 1.1 RED: `puls3_server/test/unit/ledger/xdr_invoke_encoder_test.dart`: `ScArg.string` discriminant 14, padding (`id`), empty, multi-byte.
- [ ] 1.2 GREEN: add `ScArg.string` in `puls3_server/lib/src/ledger/xdr_invoke_encoder.dart`.
- [ ] 1.3 RED: `puls3_server/test/unit/ledger/soroban_ledger_test.dart`: `totalAgents` (15, 0, malformed to `LedgerUnavailable`), `agentMetadata` (present, void to null, key sent as string), HTTP 503.
- [ ] 1.4 GREEN: add `totalAgents`, `agentMetadata` in `puls3_server/lib/src/ledger/soroban_ledger.dart`.

## Unit 2: Models and generation

- [ ] 2.1 Create `puls3_server/lib/src/agent/agent_summary.spy.yaml` (no rating).
- [ ] 2.2 Create `puls3_server/lib/src/agent/agent_catalog_unavailable.spy.yaml`.
- [ ] 2.3 Run `serverpod generate` in `puls3_server`; commit output in `puls3_server/lib/src/generated/` and `puls3_client/lib/src/protocol/`.
- [ ] 2.4 Revert any root `pubspec.lock` change (`git checkout -- pubspec.lock`); local Dart is 3.10.

## Unit 3: Validation and service

- [ ] 3.1 Add `meta: ^1.17.0` to `puls3_server/pubspec.yaml`.
- [ ] 3.2 Create `puls3_server/lib/src/agent/registry_reader.dart` (port; `SorobanLedger implements RegistryReader`).
- [ ] 3.3 RED: `puls3_server/test/unit/agent/agent_metadata_test.dart`: skills JSON, price bounds (2^53-1 ok, 2^53 rejected, 0/-5/abc), name/description length, invalid model to null.
- [ ] 3.4 GREEN: `puls3_server/lib/src/agent/agent_metadata.dart`.
- [ ] 3.5 RED: `puls3_server/test/unit/agent/agent_catalog_service_test.dart`: orphans skipped (0-6), empty registry, dedupe, order, concurrency <= 4, TTL hit/expiry, stale fallback, unavailable without cache, `get` unknown null, single in-flight refresh, `LedgerException` aborts refresh.
- [ ] 3.6 GREEN: `puls3_server/lib/src/agent/agent_catalog_service.dart`.

## Unit 4: Endpoint

- [ ] 4.1 RED: `puls3_server/test/unit/agent/agent_endpoint_test.dart`: override serves fake data; `get` during outage throws.
- [ ] 4.2 GREEN: `puls3_server/lib/src/agent/agent_endpoint.dart` (lazy default, 8 s timeout, `@visibleForTesting` setter).
- [ ] 4.3 Rerun `serverpod generate`; commit generated endpoint output; revert `pubspec.lock`.

## Unit 5: Gates and docs

- [ ] 5.1 Run `dart test test/unit` and `dart analyze --fatal-infos` in `puls3_server`; both clean.
- [ ] 5.2 Run `serverpod generate` then `git diff --exit-code puls3_server puls3_client`; clean.
- [ ] 5.3 Update server docs (`puls3_server/README.md`) with the `agent` endpoint, env vars and cache/outage behaviour.
