# Design: Server Agent Catalog Endpoint

## Technical Approach

A read-only `agent` endpoint serves `AgentSummary` values built from identity-registry metadata (proposal Option A). A pure-Dart `AgentCatalogService` (no `Session`) depends on a narrow `RegistryReader` port that `SorobanLedger` implements. The endpoint only delegates; caching, validation and failure policy live in the service.

## Architecture Decisions

| Topic | Options | Tradeoff | Decision |
|---|---|---|---|
| Port location | `RegistryReader` in `ledger/` vs `agent/` | Consumer-owned port keeps the service independent of Soroban | `agent/registry_reader.dart`; `SorobanLedger implements LedgerPort, RegistryReader` |
| Service output | Domain record + mapper vs generated models | Mapper adds code with no second consumer | Service returns generated `AgentSummary` and throws generated `AgentCatalogUnavailable` |
| Injection | Constructor vs static override | Generated `Endpoints()` calls no-arg constructors | Static lazy default + `@visibleForTesting` setter |
| Per-agent read error | Skip agent vs abort refresh | Skipping on outage yields a silently partial list | Any `LedgerException` aborts the refresh; only missing/invalid metadata skips |
| Duplicate metadata `id` | Error vs keep one | Orphans may repeat ids | Keep the highest `registryId` (newest registration) |
| `meta` package | Plain static setter vs `@visibleForTesting` | Annotation needs a direct dependency (`depend_on_referenced_packages`) | Add `meta: ^1.17.0` (version already resolved in `pubspec.lock`) |

## Data Flow

    AgentEndpoint.list/get ──> AgentCatalogService ──> RegistryReader (SorobanLedger)
                                   │ cache (60 s)            └─> SorobanRpcClient (8 s timeout)
                                   └─ stale fallback / AgentCatalogUnavailable

Refresh algorithm:
1. `total = totalAgents()`; ids `0..total-1`.
2. Four workers pull ids from a shared iterator (no new package).
3. Per agent, sequentially: read `id`; `null` or invalid ⇒ skip (drops orphans cheaply). Then `name`, `description`, `skills`, `priceUsdcStroops` (any missing/invalid ⇒ skip), then `model` (optional), then `agentWallet`.
4. Validation mirrors `scripts/seed-demo-agents.sh`: strict UTF-8; `id` non-empty; `name` 3-48 chars; `description` 10-280; `skills` JSON array of 1-5 ids matching `^[a-z0-9]+(-[a-z0-9]+)*$`; `priceUsdcStroops` matches `^[1-9][0-9]*$` and ≤ 2^53-1. An invalid `model` becomes `null`.
5. De-duplicate by `id`, sort by `registryId` ascending, store with timestamp.

Cache: `list()` returns the cached list when `now - fetchedAt < 60 s` (clock injected as `DateTime Function()`). Concurrent callers share one in-flight `Future` (cleared in `whenComplete`). On `LedgerException`: return the stale list if any exists, else throw `AgentCatalogUnavailable`. An outage never yields `[]`. `get(id)` searches `list()`; unknown ⇒ `null`.

## File Changes

| File | Action | Description |
|---|---|---|
| `puls3_server/lib/src/agent/agent_summary.spy.yaml` | Create | `class: AgentSummary` |
| `puls3_server/lib/src/agent/agent_catalog_unavailable.spy.yaml` | Create | `exception: AgentCatalogUnavailable` |
| `puls3_server/lib/src/agent/registry_reader.dart` | Create | Port |
| `puls3_server/lib/src/agent/agent_metadata.dart` | Create | Pure validators/parser |
| `puls3_server/lib/src/agent/agent_catalog_service.dart` | Create | Enumeration, cache, fallback |
| `puls3_server/lib/src/agent/agent_endpoint.dart` | Create | `list`, `get`, wiring |
| `puls3_server/lib/src/ledger/soroban_ledger.dart` | Modify | `totalAgents`, `agentMetadata` |
| `puls3_server/lib/src/ledger/xdr_invoke_encoder.dart` | Modify | `ScArg.string` (`SCV_STRING = 14`) |
| `puls3_server/pubspec.yaml` | Modify | `meta` dependency |
| `puls3_server/lib/src/generated/**`, `test/integration/test_tools/**`, `puls3_client/lib/src/protocol/**` | Regenerate | `serverpod generate` output, committed |

## Interfaces / Contracts

```yaml
class: AgentSummary
fields:
  id: String            # metadata id, e.g. agt-001
  registryId: int
  name: String
  description: String
  skills: List<String>  # kebab ids
  priceUsdcStroops: int
  wallet: String?       # G... address
  model: String?
---
exception: AgentCatalogUnavailable
fields:
  message: String
```

```dart
abstract interface class RegistryReader {
  Future<int> totalAgents();                              // readU32({"u32": n})
  Future<Uint8List?> agentMetadata(AgentId id, String key); // readOptional(v, readBytes): "void" -> null
  Future<StellarAddress?> agentWallet(AgentId id);
}
```

`get_metadata` returns `Option<Bytes>` and never fails for absent keys, so no `absentErrors`. `ScArg.string` writes `uint32(14)` then the XDR string (length, UTF-8 bytes, zero padding).

Endpoint: `static AgentCatalogService? _service`; getter builds the default on first use (`StellarConfig.fromEnvironment(Platform.environment)`, one process-lifetime `http.Client`, `SorobanRpcClient(timeout: 8 s)`); `@visibleForTesting static set service(AgentCatalogService? s)`.

## Generation Steps

1. `cd puls3_server && serverpod generate` with the installed `serverpod_cli` 3.4.13 (same as CI).
2. Commit all generated server, test-tools and client files.
3. Local Dart is 3.10 while `pubspec.lock` declares `dart >=3.11.0`: revert any `pubspec.lock` change (`git checkout -- pubspec.lock`).

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit | `ScArg.string` bytes (incl. padding) | Expected byte arrays |
| Unit | `totalAgents`, `agentMetadata` present/void, malformed | `MockClient` + fixtures (`simulate_total_agents.json`, `simulate_get_metadata_present.json`, `simulate_get_metadata_void.json`), captured from testnet RPC, not hand-invented |
| Unit | Validators; skip rules; dedupe; order; concurrency ≤ 4; TTL hit/expiry; stale fallback; unavailable without cache; single in-flight refresh | Fake `RegistryReader` with counters/completers; fake clock |
| Integration (optional) | Endpoint wiring with override | `withServerpod`; needs Postgres/Redis, runs in CI only; reset override in `tearDown` |

Strict TDD: write each RED test before its implementation.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. No database tables (models have no `table:`).

## Open Questions

- [ ] Whether generated output from local Dart 3.10 matches CI byte-for-byte; the CI diff gate decides, regenerate with Dart 3.11 if not.
