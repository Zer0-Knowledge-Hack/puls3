# Exploration: fix-server-agent-catalog-endpoint

Full analysis: engram `sdd/fix-server-agent-catalog-endpoint/explore` (obs 416).

## Current state

- Endpoints are `class XEndpoint extends Endpoint` under `puls3_server/lib/src/<area>/`; models are `*.spy.yaml`. `serverpod generate` rewrites `generated/`, the test tools and the `puls3_client` protocol copies. CI runs `serverpod generate` with `serverpod_cli 3.4.13` and fails on any `git diff` in `puls3_server`/`puls3_client`, so generated output must be committed byte-identical.
- The generated `Endpoints()` builds endpoints without constructor arguments, so dependencies are not injected through the constructor.
- `SorobanLedger` (read-only) exposes `agentExists`, `agentUri`, `agentWallet`, `escrowJob`, `findPayment`. It lacks `totalAgents()` (`total_agents`) and `agentMetadata(AgentId, key)` (`get_metadata`), and the encoder lacks a string argument (`ScArg.string`).
- On chain: 15 agents. Ids 0-6 are superseded orphans; ids 7-14 are `puls3://demo/agt-001..008`. Seeded metadata keys: `id`, `name`, `description`, `skills` (JSON array string of kebab ids), `priceUsdcStroops`, `model`. There is no rating on chain and no list function.

## Options for display data

| Option | Verdict |
|---|---|
| A. Registry metadata | Recommended: single source of truth, already validated by the seed script |
| B. agentURI document | `puls3://` URIs are not fetchable |
| C. Ship `demo-agents.json` in the server | Duplicates data and defeats the purpose |

## Recommended design

- Spy model `AgentSummary { id, registryId, name, description, skills (kebab ids), priceUsdcStroops, wallet?, model? }`. No rating.
- `AgentEndpoint.list(Session)` and `get(Session, String id)` (id is the metadata id; unknown id returns null; `get` reads the cached list).
- `AgentCatalogService` in pure Dart over a narrow `RegistryReader` interface (`totalAgents`, `agentUri`, `agentMetadata`, `agentWallet`) implemented by `SorobanLedger`. Enumerate ids `0..total-1`, skip agents with missing or invalid metadata (this drops the orphans), per-agent parallelism with bounded concurrency.
- 60 s in-memory cache; stale cache is returned if the chain is unavailable; otherwise a typed serializable exception model `AgentCatalogUnavailable`. An empty list is never returned for an outage.
- Wiring: the endpoint lazily builds a default service from `StellarConfig.fromEnvironment`, `http.Client` and an 8 s RPC timeout, with a `@visibleForTesting` override.

## Defaults decided

Timeout 8 s; cache TTL 60 s; skills kept as kebab ids; no rating; lookup by metadata id; typed unavailable exception.

## Risks

- Orphan metadata not read from the chain; the skip-on-invalid rule is the safeguard.
- Cold list is about 85 simulate calls on a public node: bound concurrency (about 4).
- `serverpod_cli` must match CI's 3.4.13 or the generated-diff gate fails.
- `rating` and `stellarAddress` in the Flutter `Agent` have no on-chain source; the Flutter change decides the rating default.
- Archived registry state surfaces as `LedgerUnavailable`.

## Budget

About 250-300 hand-written lines excluding generated files. Single PR; `size:exception` only if generated files push it over.
