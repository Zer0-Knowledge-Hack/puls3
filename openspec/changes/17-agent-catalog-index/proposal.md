# Proposal: Agent Catalog Index

## Intent

The catalog endpoint currently reads the whole catalog from the chain and only
caches it in memory (`AgentCatalogService`). The chain stays the source of
truth, but a read is slow, and nothing survives a restart or a chain outage.
Issue #17 asks for a Postgres index synced from the identity registry, with a
resume cursor, so the endpoint can serve list/get from the index.

## Scope

### In Scope

- RPC event reads: `getLatestLedger` and `getEvents` on `SorobanRpcClient`,
  plus `registry_events.dart` to decode `registered`, `metadata_set` and
  `uri_updated` (`xdrFormat: "json"`).
- `RegistryEventReader` port and `SorobanRegistryEventReader` adapter
  (cursor pagination).
- `AgentRecord` and `CatalogIndexState` models, `AgentIndexRepository` port and
  `ServerpodAgentIndexRepository` (Serverpod ORM, idempotent upsert by registry
  id, resume cursor per network).
- `CatalogIndexer`: first pass bootstraps from registry state (RPC keeps only
  ~7 days of events); later passes read events after the cursor and hydrate the
  affected agents from state; any agent missing from the index is always
  hydrated.
- `IndexedAgentCatalogService`: serves the catalog from the index with an
  on-chain fallback while the index is empty.
- `AgentEndpoint` depends only on `CatalogReader`; Soroban wiring moves to
  `agent_catalog_wiring.dart`.
- Indexer loop wiring (`PULS3_INDEXER_ENABLED`,
  `PULS3_INDEXER_INTERVAL_SECONDS`), started from `server.dart`.

### Out of Scope

- Pagination and server-side search (the merged #8 contract filters the
  returned catalog in Flutter; tracked as a follow-up).
- Reputation (#21), agent registration (#18), Flutter changes.
- Reading events older than the RPC retention window.

## Capabilities

### New Capabilities

- `catalog-index`: the durable index, its upsert-by-registry-id rule, newest
  registration per metadata id, and the per-network resume cursor.
- `catalog-indexer`: bootstrap-from-state, incremental event sync, recovery of
  missing agents, cursor behaviour on a retention gap, and outage handling.
- `indexed-agent-catalog`: serving list/get from the index, and the chain
  fallback while the index is empty.

### Modified Capabilities

- `agent-catalog-endpoint`: the endpoint now reads through `CatalogReader`
  (index first) instead of constructing the RPC client itself; the on-chain
  service is reused as the fallback.

## Approach

A hybrid sync keeps the index correct without depending on event retention:
bootstrap from `total_agents` + per-agent metadata, then use `getEvents` after
the stored cursor to find changed agents and re-hydrate them from state. Writes
are idempotent (`upsert` by unique `registryId`), so re-running a pass never
duplicates rows. Reads never touch the chain while the index has rows.

## Affected Areas

| Component | Area | Impact |
|-----------|------|--------|
| server | `lib/src/ledger/` | `getEvents`/`getLatestLedger`, event parser + reader |
| server | `lib/src/agent/` | index models, repository, indexer, indexed service, wiring |
| server | `lib/src/generated/`, `puls3_client/` | Regenerated for the two new models |
| server | `migrations/` | New `agent_record` and `catalog_index_state` tables |
| server | `test/unit`, `test/integration` | New unit + integration tests |
| root | `.env.example`, `puls3_server/README.md` | Indexer variables |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `getEvents` JSON shape differs from what we parse | Low | Fixtures recorded from testnet; a malformed event is skipped |
| Cursor falls outside retention after downtime | Med | Reset the cursor on `RpcRequestRejected`; recover missing agents from state |
| Generated-diff CI gate | Med | Commit generated output and migration; verify with `serverpod generate` |
| Orphan/superseded registrations | Low | Keep newest per metadata id; skip invalid metadata |

## Rollback Plan

Revert the PR commits and drop the two new tables with a follow-up migration.
The endpoint keeps working because the on-chain `AgentCatalogService` remains
as the fallback; disabling `PULS3_INDEXER_ENABLED` (the default) stops indexing.

## Dependencies

- Deployed identity registry with seeded metadata (ids 7-14).
- Serverpod 4.0.4, the repo's pinned version.

## Success Criteria

- [ ] After seeding, `list` returns the demo agents; orphans are skipped and
      superseded registrations are deduped.
- [ ] Two indexer passes create no duplicate rows and the cursor resumes.
- [ ] A chain outage still serves the index; the indexer logs and retries.
- [ ] `dart analyze --fatal-infos`, `dart test`, and the generated-diff check pass.
