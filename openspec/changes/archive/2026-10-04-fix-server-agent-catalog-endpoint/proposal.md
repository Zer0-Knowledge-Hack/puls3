# Proposal: Server Agent Catalog Endpoint

## Intent

The Flutter catalog uses mock data. The server needs a read-only `agent` endpoint that serves the catalog from the on-chain identity registry, so the registry stays the single source of truth.

## Scope

### In Scope
- `AgentSummary` spy model (`id`, `registryId`, `name`, `description`, `skills` kebab ids, `priceUsdcStroops`, `wallet?`, `model?`); no rating.
- `AgentCatalogUnavailable` serializable exception model.
- `AgentEndpoint.list(Session)` and `get(Session, String id)` (metadata id; unknown returns null).
- `AgentCatalogService` (pure Dart) over a `RegistryReader` interface.
- `SorobanLedger`: `totalAgents()`, `agentMetadata(AgentId, key)`; encoder `ScArg.string`.
- Committed `serverpod generate` output (server + `puls3_client`).

### Out of Scope
- Flutter wiring, rating/reputation, registry writes, hire flow.

## Capabilities

### New Capabilities
- `agent-catalog-endpoint`: list/get behaviour, skip-invalid rule, 60 s cache, stale fallback, typed unavailable failure.
- `registry-metadata-reads`: `totalAgents`, `agentMetadata`, Soroban string argument encoding.

### Modified Capabilities
- None.

## Approach

Option A (registry metadata). Enumerate ids `0..total-1` with bounded concurrency (~4); skip agents with missing or invalid metadata (drops orphans 0-6). Cache the whole list for 60 s; on `LedgerUnavailable` return stale cache, otherwise throw `AgentCatalogUnavailable` (never an empty list for an outage). The endpoint lazily builds a default service (`StellarConfig.fromEnvironment`, `http.Client`, 8 s RPC timeout) with a `@visibleForTesting` override.

## Affected Areas

| Component | Area | Impact |
|-----------|------|--------|
| server | `puls3_server/lib/src/agent/` | New endpoint, service, models |
| server | `puls3_server/lib/src/ledger/` | New reads + `ScArg.string` |
| server | `puls3_server/lib/src/generated/` | Regenerated |
| client | `puls3_client/lib/src/protocol/` | Regenerated |
| server | `puls3_server/test/unit/` | Service, ledger, encoder tests |
| domain, app, contracts | — | None |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Generated-diff CI gate fails | Med | Use `serverpod_cli` 3.4.13 (installed, matches CI) |
| Cold list (~85 simulate calls) slow or rate-limited | Med | Concurrency ~4, 8 s timeout, cache |
| Orphan or malformed metadata | Low | Skip-on-invalid validation |
| Archived registry state | Low | Surfaces as unavailable / stale cache |

## Rollback Plan

Revert the single PR commit(s); remove the `agent` endpoint and models, rerun `serverpod generate`, commit. No migrations, chain or client consumers affected.

## Dependencies

- Deployed identity registry with seeded metadata (ids 7-14).
- `serverpod_cli` 3.4.13.

## Review Workload

About 250-300 hand-written lines plus generated files. Single PR; label `size:exception` only if generated files exceed 400 lines.

## Success Criteria

- [ ] `list` returns the 8 seeded agents (`agt-001..008`) and no orphans.
- [ ] `get('agt-001')` returns it; unknown id returns null.
- [ ] Outage with cache returns stale data; without cache throws `AgentCatalogUnavailable`.
- [ ] `dart analyze --fatal-infos`, `dart test`, and the generated-diff check pass in CI.
